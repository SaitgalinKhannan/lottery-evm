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

    // Константы для лотереи
    uint256 constant TICKET_PRICE = 0.01 ether;
    uint256 constant MAX_TICKETS = 10; // Уменьшаем для тестов

    receive() external payable {}

    // Настройка перед каждым тестом
    function setUp() public {
        // Создаем аккаунты для тестирования
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);

        // Даем пользователям ETH для покупки билетов
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);

        // Деплоим контракт
        lottery = new SingleLottery(TICKET_PRICE, MAX_TICKETS);
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

    // Тест проведения розыгрыша
    function testDrawLottery() public {
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
        uint256 ownerBalanceBefore = address(this).balance;
        uint256 user1BalanceBefore = user1.balance;
        uint256 user2BalanceBefore = user2.balance;
        uint256 user3BalanceBefore = user3.balance;

        // Проводим розыгрыш
        lottery.drawLottery();

        // Проверяем, что деньги были распределены
        uint256 totalPrize = TICKET_PRICE * MAX_TICKETS;
        uint256 ownerFee = (totalPrize * 10) / 100;

        // Проверяем, что призовой фонд полностью распределен
        assertEq(address(lottery).balance, 0);

        // Проверяем, что владелец получил свою комиссию
        assertEq(address(this).balance - ownerBalanceBefore, ownerFee);

        // Общая сумма возвращенных средств (включая выигрыш)
        uint256 totalReturned = (user1.balance - user1BalanceBefore) +
            (user2.balance - user2BalanceBefore) +
            (user3.balance - user3BalanceBefore);

        // Должно быть равно 90% от призового фонда
        assertEq(totalReturned, (totalPrize * 90) / 100);
    }

    // Тест на ошибку при попытке провести розыгрыш с недостаточным количеством участников
    function testRevertWhenDrawWithoutEnoughParticipants() public {
        // Только один участник
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        // Должно вызвать ошибку, так как нужно минимум два участника
        vm.expectRevert("At least two participants required");
        lottery.drawLottery();
    }

    // Тест проведения розыгрыша с двумя участниками
    function testDrawLotteryWithTwoParticipants() public {
        // Два участника покупают билеты
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        vm.prank(user2);
        lottery.buyTickets{value: TICKET_PRICE * 2}(2);

        // Записываем балансы до розыгрыша
        uint256 ownerBalanceBefore = address(this).balance;
        uint256 user1BalanceBefore = user1.balance;
        uint256 user2BalanceBefore = user2.balance;

        // Проводим розыгрыш - теперь должно сработать
        lottery.drawLottery();

        // Проверяем, что деньги были распределены
        uint256 totalPrize = TICKET_PRICE * 5; // Всего продано 5 билетов
        uint256 ownerFee = (totalPrize * 10) / 100;

        // После проведения розыгрыша
        uint256 user1After = user1.balance;
        uint256 user2After = user2.balance;

        // Общая сумма возвращенных средств (включая выигрыш для одного из них)
        uint256 totalReturned = (user1After - user1BalanceBefore) +
            (user2After - user2BalanceBefore);

        // Должно быть равно 90% от призового фонда
        assertEq(totalReturned, totalPrize * 90 / 100);

        // Проверяем, что владелец получил свою комиссию
        assertEq(address(this).balance - ownerBalanceBefore, ownerFee);

        // Проверяем, что призовой фонд полностью распределен
        assertEq(address(lottery).balance, 0);
    }

    // Тест на возврат средств
    function testRefundAll() public {
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        vm.prank(user2);
        lottery.buyTickets{value: TICKET_PRICE * 2}(2);

        uint256 user1BalanceBefore = user1.balance;
        uint256 user2BalanceBefore = user2.balance;

        // Возвращаем деньги
        lottery.refundAll();

        // Проверяем, что деньги вернулись
        assertEq(user1.balance - user1BalanceBefore, TICKET_PRICE * 3);
        assertEq(user2.balance - user2BalanceBefore, TICKET_PRICE * 2);
        assertEq(address(lottery).balance, 0);
        assertEq(lottery.ticketsSold(), 0);
    }

    // Тест на ошибку, если не владелец пытается провести розыгрыш
    function testRevertWhenNonOwnerDraw() public {
        // Заполняем все билеты
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        vm.prank(user2);
        lottery.buyTickets{value: TICKET_PRICE * 4}(4);

        vm.prank(user3);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        // Пытаемся провести розыгрыш от имени не владельца
        vm.prank(user1);
        vm.expectRevert("Only owner can call this function");
        lottery.drawLottery();
    }

    // Тест на ошибку, если не владелец пытается вернуть средства
    function testRevertWhenNonOwnerRefund() public {
        vm.prank(user1);
        lottery.buyTickets{value: TICKET_PRICE * 3}(3);

        // Пытаемся вернуть средства от имени не владельца
        vm.prank(user1);
        vm.expectRevert("Only owner can call this function");
        lottery.refundAll();
    }
}
