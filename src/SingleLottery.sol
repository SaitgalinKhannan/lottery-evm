// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract SingleLottery {
    address public owner;
    uint256 public immutable TICKET_PRICE;
    uint256 public immutable MAX_TICKETS;
    uint256 public immutable OWNER_FEE_PERCENT;      // Процент комиссии владельца
    uint256 public immutable WINNER_PRIZE_PERCENT;   // Процент приза победителю
    uint256 public immutable RETURNED_PRIZE_PERCENT; // Процент возврата участникам
    uint256 public ticketsSold = 0;
    bool public lotteryFinished = false;

    // Массив для хранения адресов участников (без дубликатов)
    address[] public participants;
    mapping(address => bool) public isParticipant;
    // Массив всех проданных билетов
    address[] public ticketOwners;
    // Маппинг для хранения информации об участниках
    mapping(address => uint256) public participantTickets;

    // Для клейма вознаграждений
    mapping(address => uint256) public pendingRewards;
    address public winner;
    uint256 public winnerPrize;

    // События
    event TicketPurchased(address buyer, uint256 amount);
    event LotteryDrawn(address winner, uint256 winnerPrize);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RewardClaimed(address claimer, uint256 amount);

    // Модификаторы
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryOpen() {
        require(!lotteryFinished, "Lottery is already finished");
        require(ticketsSold < MAX_TICKETS, "All tickets have been sold");
        _;
    }

    modifier lotteryReady() {
        require(participants.length >= 2, "At least two participants required");
        require(ticketsSold > 0, "No tickets sold yet");
        _;
    }

    constructor(
        uint256 _ticketPrice,
        uint256 _maxTickets,
        uint256 _ownerFeePercent,
        uint256 _winnerPrizePercent,
        uint256 _returnedPrizePercent
    ) {
        require(_ticketPrice > 0, "Ticket price must be greater than zero");
        require(_maxTickets > 0, "Max tickets must be greater than zero");
        // Проверяем, что проценты в сумме дают 100%
        require(
            _ownerFeePercent + _winnerPrizePercent + _returnedPrizePercent == 100,
            "Prize distribution must sum to 100%"
        );

        owner = msg.sender;
        TICKET_PRICE = _ticketPrice;
        MAX_TICKETS = _maxTickets;
        OWNER_FEE_PERCENT = _ownerFeePercent;
        WINNER_PRIZE_PERCENT = _winnerPrizePercent;
        RETURNED_PRIZE_PERCENT = _returnedPrizePercent;
    }

    // Функция покупки билетов
    function buyTickets(uint256 _amount) public payable lotteryOpen {
        require(_amount > 0, "You must buy at least one ticket");
        require(ticketsSold + _amount <= MAX_TICKETS, "Not enough tickets available");
        require(msg.value == _amount * TICKET_PRICE, "Incorrect ETH amount sent");

        // Записываем информацию о покупателе
        participantTickets[msg.sender] += _amount;

        // Добавляем адрес как участника, если это первая покупка
        if (!isParticipant[msg.sender]) {
            participants.push(msg.sender);
            isParticipant[msg.sender] = true;
        }

        // Добавляем билеты в массив
        for (uint256 i = 0; i < _amount; i++) {
            ticketOwners.push(msg.sender);
            ticketsSold++;
        }

        emit TicketPurchased(msg.sender, _amount);
    }

    // Функция для проведения розыгрыша с внешним источником "случайности"
    function drawLottery(uint256 _randomSeed) public onlyOwner lotteryReady {
        require(!lotteryFinished, "Lottery is already finished");
        require(address(this).balance == ticketsSold * TICKET_PRICE, "Prize pool incorrect");

        // Отмечаем лотерею как завершенную
        lotteryFinished = true;

        // Генерируем случайное число используя внешний seed
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, ticketOwners, _randomSeed))) % ticketsSold;
        winner = ticketOwners[randomIndex];

        // Расчет призов
        uint256 totalPrize = address(this).balance;
        uint256 ownerFee = totalPrize * OWNER_FEE_PERCENT / 100;
        winnerPrize = totalPrize * WINNER_PRIZE_PERCENT / 100;
        uint256 returnedPrize = totalPrize * RETURNED_PRIZE_PERCENT / 100;

        // Устанавливаем призы для клейма
        pendingRewards[owner] = ownerFee;
        pendingRewards[winner] += winnerPrize;

        // Устанавливаем возвраты для всех участников
        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            if (participantTickets[participant] > 0) {
                uint256 participantShare = returnedPrize * participantTickets[participant] / ticketsSold;
                pendingRewards[participant] += participantShare;
            }
        }

        emit LotteryDrawn(winner, winnerPrize);
    }

    // Функция для клейма вознаграждений
    function claimReward() public {
        uint256 reward = pendingRewards[msg.sender];
        require(reward > 0, "No rewards to claim");

        // Обнуляем вознаграждение перед отправкой (защита от reentrancy)
        pendingRewards[msg.sender] = 0;

        // Отправляем вознаграждение
        (bool sent,) = payable(msg.sender).call{value: reward}("");
        require(sent, "Failed to send reward");

        emit RewardClaimed(msg.sender, reward);
    }

    // Передача прав владельца
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // Получение текущего баланса контракта
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Сколько еще осталось билетов
    function getRemainingTickets() public view returns (uint256) {
        return MAX_TICKETS - ticketsSold;
    }

    // Получение информации о моих билетах и ожидающих наградах
    function getMyInfo() public view returns (uint256 tickets, uint256 rewards) {
        return (participantTickets[msg.sender], pendingRewards[msg.sender]);
    }

    // На случай, если нужно вернуть все деньги участникам (например, если розыгрыш отменяется)
    function emergencyRefund() public onlyOwner {
        require(!lotteryFinished, "Lottery already finished");

        // Отмечаем лотерею как завершенную
        lotteryFinished = true;

        // Устанавливаем возвраты для всех участников
        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            if (participantTickets[participant] > 0) {
                uint256 refundAmount = participantTickets[participant] * TICKET_PRICE;
                pendingRewards[participant] += refundAmount;
            }
        }
    }
}