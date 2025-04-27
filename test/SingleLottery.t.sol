// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// Импортируем тестовую библиотеку Foundry
import "forge-std/Test.sol";
// Импортируем наш контракт
import "../src/SingleLottery.sol";

contract SingleLotteryTest is Test {
    // Объявляем переменные
    SingleLottery public lottery;
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public newOwner;

    // Константы для лотереи
    uint256 constant TICKET_PRICE = 0.01 ether;
    uint256 constant MAX_TICKETS = 10; // Уменьшаем для тестов
    uint256 constant RANDOM_SEED = 12345; // Случайное число для розыгрыша
    uint256 public immutable OWNER_FEE_PERCENT = 20;
    uint256 public immutable WINNER_PRIZE_PERCENT = 30;
    uint256 public immutable RETURNED_PRIZE_PERCENT = 50;

    receive() external payable {}

    // Настройка перед каждым тестом
    function setUp() public {
        // Создаем аккаунты для тестирования
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);
        newOwner = address(0x4);

        // Даем пользователям ETH для покупки билетов
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);
        vm.deal(newOwner, 1 ether);

        // Деплоим контракт
        lottery = new SingleLottery(TICKET_PRICE, MAX_TICKETS, 20, 30, 50);
    }

    // Тест покупки билетов
    function testBuyTickets() public {
        // Покупаем билеты от имени user1
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        // Проверяем, что билеты были куплены
        assertEq(lottery.ticketsSold(), 3);
        assertEq(lottery.participantTickets(user1), 3);
        assertEq(lottery.getRemainingTickets(), MAX_TICKETS - 3);
        assertEq(address(lottery).balance, TICKET_PRICE * 3);
    }

    // Тест на ошибку при неправильной сумме
    function testRevertWhenIncorrectPayment() public {
        vm.prank(user1);
        // Отправляем меньше денег, чем нужно
        vm.expectRevert("Incorrect ETH amount sent");
        lottery.buyTickets{value: TICKET_PRICE - 1 wei}(1);
    }

    // Тест на покупку слишком большого количества билетов
    function testRevertWhenTooManyTickets() public {
        vm.prank(user1);
        // Пытаемся купить больше билетов, чем доступно
        vm.expectRevert("Not enough tickets available");
        lottery.buyTickets{value: TICKET_PRICE * (MAX_TICKETS + 1)}(
            MAX_TICKETS + 1
        );
    }

    // Тест проведения розыгрыша и клейма наград
    function testDrawLotteryAndClaim() public {
        // Заполняем все билеты
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        vm.prank(user2);
        lottery.buyTickets{value: TICKET_PRICE * 4}(4);

        vm.prank(user3);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        // Проверяем, что все билеты проданы
        assertEq(lottery.ticketsSold(), MAX_TICKETS);

        // Записываем балансы до розыгрыша
        uint256 user1BalanceBefore = user1.balance;
        uint256 user2BalanceBefore = user2.balance;
        uint256 user3BalanceBefore = user3.balance;
        uint256 ownerBalanceBefore = address(this).balance;

        // Проводим розыгрыш с использованием seed
        lottery.drawLottery(RANDOM_SEED);

        // Проверяем, что лотерея завершена
        assertTrue(lottery.lotteryFinished());

        // Клеймим награду для владельца
        uint256 ownerPending = lottery.pendingRewards(owner);
        lottery.claimReward();

        // Проверяем, что владелец получил свою комиссию
        assertEq(address(this).balance - ownerBalanceBefore, ownerPending);

        // Клеймим награды для user1
        vm.prank(user1);
        uint256 user1Pending = lottery.pendingRewards(user1);
        vm.prank(user1);
        lottery.claimReward();

        // Клеймим награды для user2
        vm.prank(user2);
        uint256 user2Pending = lottery.pendingRewards(user2);
        vm.prank(user2);
        lottery.claimReward();

        // Клеймим награды для user3
        vm.prank(user3);
        uint256 user3Pending = lottery.pendingRewards(user3);
        vm.prank(user3);
        lottery.claimReward();

        // Проверяем, что награды были распределены правильно
        assertEq(user1.balance - user1BalanceBefore, user1Pending);
        assertEq(user2.balance - user2BalanceBefore, user2Pending);
        assertEq(user3.balance - user3BalanceBefore, user3Pending);

        // Общая сумма возвращенных средств (включая выигрыш)
        uint256 totalReturned = user1Pending + user2Pending + user3Pending;

        // Должно быть равно 90% от призового фонда
        uint256 totalPrize = TICKET_PRICE * MAX_TICKETS;
        assertEq(totalReturned, (totalPrize * (RETURNED_PRIZE_PERCENT + WINNER_PRIZE_PERCENT)) / 100);

        // Проверяем, что призовой фонд полностью распределен
        assertEq(address(lottery).balance, 0);
    }

    // Тест на ошибку при попытке провести розыгрыш с недостаточным количеством участников
    function testRevertWhenDrawWithoutEnoughParticipants() public {
        // Только один участник
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        // Должно вызвать ошибку, так как нужно минимум два участника
        vm.expectRevert("At least two participants required");
        lottery.drawLottery(RANDOM_SEED);
    }

    // Тест проведения розыгрыша с двумя участниками
    function testDrawLotteryWithTwoParticipants() public {
        // Два участника покупают билеты
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        vm.prank(user2);
        lottery.buyTickets{value: TICKET_PRICE * 2}(2);

        // Проводим розыгрыш - теперь должно сработать
        lottery.drawLottery(RANDOM_SEED);

        // Проверяем, что награды начислены
        uint256 totalPrize = TICKET_PRICE * 5; // Всего продано 5 билетов
        uint256 ownerFee = (totalPrize * OWNER_FEE_PERCENT) / 100;

        assertEq(lottery.pendingRewards(owner), ownerFee);

        // Общая сумма ожидающих наград для участников
        uint256 user1Pending = lottery.pendingRewards(user1);
        uint256 user2Pending = lottery.pendingRewards(user2);

        // Должно быть равно 90% от призового фонда
        assertEq(user1Pending + user2Pending, totalPrize * (RETURNED_PRIZE_PERCENT + WINNER_PRIZE_PERCENT) / 100);
    }

    // Тест на экстренный возврат средств
    function testEmergencyRefund() public {
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        vm.prank(user2);
        lottery.buyTickets{value: TICKET_PRICE * 2}(2);

        // Вызываем экстренный возврат
        lottery.emergencyRefund();

        // Проверяем, что лотерея завершена
        assertTrue(lottery.lotteryFinished());

        // Проверяем, что в pendingRewards записаны верные суммы
        assertEq(lottery.pendingRewards(user1), TICKET_PRICE * 3);
        assertEq(lottery.pendingRewards(user2), TICKET_PRICE * 2);

        // Клеймим награды
        uint256 user1BalanceBefore = user1.balance;
        vm.prank(user1);
        lottery.claimReward();
        assertEq(user1.balance - user1BalanceBefore, TICKET_PRICE * 3);

        uint256 user2BalanceBefore = user2.balance;
        vm.prank(user2);
        lottery.claimReward();
        assertEq(user2.balance - user2BalanceBefore, TICKET_PRICE * 2);

        // Проверяем, что все средства вернулись
        assertEq(address(lottery).balance, 0);
    }

    // Тест функции getMyInfo
    function testGetMyInfo() public {
        // Добавляем двух участников, чтобы пройти проверку "At least two participants required"
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        vm.prank(user2);
        lottery.buyTickets{value: TICKET_PRICE * 2}(2);

        // Проверяем информацию до розыгрыша
        vm.prank(user1);
        (uint256 tickets, uint256 rewards) = lottery.getMyInfo();
        assertEq(tickets, 3);
        assertEq(rewards, 0);

        // Проводим розыгрыш
        lottery.drawLottery(RANDOM_SEED);

        // Проверяем информацию после розыгрыша
        vm.prank(user1);
        (tickets, rewards) = lottery.getMyInfo();
        assertEq(tickets, 3);
        assertTrue(rewards > 0); // Должны быть какие-то награды
    }

    // Тест передачи прав владельца
    function testTransferOwnership() public {
        // Передаем права владельца
        lottery.transferOwnership(newOwner);

        // Проверяем, что владелец изменился
        assertEq(lottery.owner(), newOwner);

        // Старый владелец больше не может вызывать onlyOwner функции
        vm.expectRevert("Only owner can call this function");
        lottery.drawLottery(RANDOM_SEED);

        // Заполним лотерею билетами для проверки
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        vm.prank(user2);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        // Новый владелец может вызывать onlyOwner функции
        vm.prank(newOwner);
        lottery.emergencyRefund(); // Должно работать без ошибок
    }

    // Тест на повторный клейм
    function testRevertOnDoubleClaimReward() public {
        // Заполняем лотерею
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);
        vm.prank(user2);
        lottery.buyTickets{value: TICKET_PRICE * 2}(2);

        // Проводим розыгрыш
        lottery.drawLottery(RANDOM_SEED);

        // Клеймим награду для user1
        vm.prank(user1);
        lottery.claimReward();

        // Пытаемся клеймить повторно
        vm.prank(user1);
        vm.expectRevert("No rewards to claim");
        lottery.claimReward();
    }

    // Тест на невозможность покупки билетов после завершения лотереи
    function testRevertBuyTicketsAfterLotteryFinished() public {
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);
        vm.prank(user2);
        lottery.buyTickets{value: TICKET_PRICE * 2}(2);

        // Завершаем лотерею
        lottery.drawLottery(RANDOM_SEED);

        // Пытаемся купить билеты
        vm.prank(user3);
        vm.expectRevert("Lottery is already finished");
        lottery.buyTickets{value: TICKET_PRICE}(1);
    }

    // Тест на невозможность проведения розыгрыша дважды
    function testRevertDrawLotteryTwice() public {
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);
        vm.prank(user2);
        lottery.buyTickets{value: TICKET_PRICE * 2}(2);

        // Проводим розыгрыш первый раз
        lottery.drawLottery(RANDOM_SEED);

        // Пытаемся провести розыгрыш второй раз
        vm.expectRevert("Lottery is already finished");
        lottery.drawLottery(RANDOM_SEED);
    }
}