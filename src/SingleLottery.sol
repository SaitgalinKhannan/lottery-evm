// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract SingleLottery {
    address public owner;
    uint256 public immutable TICKET_PRICE;
    uint256 public immutable MAX_TICKETS;
    uint256 public ticketsSold = 0;

    // Массив для хранения адресов участников (без дубликатов)
    address[] public participants;
    mapping(address => bool) public isParticipant;
    // Массив всех проданных билетов
    address[] public ticketOwners;
    // Маппинг для хранения информации об участниках
    mapping(address => uint256) public participantTickets;

    // События
    event TicketPurchased(address buyer, uint256 amount);
    event LotteryDrawn(
        address winner,
        uint256 winnerPrize,
        uint256 returnedPrize
    );

    // Модификаторы
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryOpen() {
        require(ticketsSold < MAX_TICKETS, "All tickets have been sold");
        _;
    }

    modifier lotteryReady() {
        require(participants.length >= 2, "At least two participants required");
        require(ticketsSold > 0, "No tickets sold yet");
        _;
    }

    constructor(uint256 _ticketPrice, uint256 _maxTickets) {
        owner = msg.sender;
        TICKET_PRICE = _ticketPrice;
        MAX_TICKETS = _maxTickets;
    }

    // Функция покупки билетов - добавлен учет уникальных участников
    function buyTickets(uint256 _amount) public payable lotteryOpen {
        require(_amount > 0, "You must buy at least one ticket");
        require(
            ticketsSold + _amount <= MAX_TICKETS,
            "Not enough tickets available"
        );
        require(
            msg.value == _amount * TICKET_PRICE,
            "Incorrect ETH amount sent"
        );

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

    // Функция для проведения розыгрыша
    function drawLottery() public onlyOwner lotteryReady {
        require(address(this).balance == ticketsSold * TICKET_PRICE, "Prize pool incorrect");

        // Генерируем случайное число для выбора победителя
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, ticketOwners))) % ticketsSold;
        address winner = ticketOwners[randomIndex];

        // Расчет призов
        uint256 totalPrize = address(this).balance;
        uint256 ownerFee = totalPrize * 10 / 100;       // 10% создателям
        uint256 winnerPrize = totalPrize * 10 / 100;    // 10% победителю
        uint256 returnedPrize = totalPrize * 80 / 100;  // 80% возвращается участникам

        // Отправляем приз победителю
        (bool winnerSent,) = payable(winner).call{value: winnerPrize}("");
        require(winnerSent, "Failed to send ETH to winner");

        // Возвращаем деньги участникам пропорционально количеству купленных билетов
        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            if (participantTickets[participant] > 0) {
                uint256 participantShare = returnedPrize * participantTickets[participant] / ticketsSold;
                participantTickets[participant] = 0; // Обнуляем перед отправкой

                (bool sent,) = payable(participant).call{value: participantShare}("");
                require(sent, "Failed to send ETH to participant");
            }
        }

        // Отправляем комиссию владельцу
        (bool ownerSent,) = payable(owner).call{value: ownerFee}("");
        require(ownerSent, "Failed to send ETH to owner");

        emit LotteryDrawn(winner, winnerPrize, returnedPrize);
    }

    // Получение текущего баланса контракта
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Сколько еще осталось билетов
    function getRemainingTickets() public view returns (uint256) {
        return MAX_TICKETS - ticketsSold;
    }

    // На случай, если нужно вернуть все деньги участникам (например, если розыгрыш отменяется)
    function refundAll() public onlyOwner {
        for (uint256 i = 0; i < ticketOwners.length; i++) {
            address participant = ticketOwners[i];
            if (participantTickets[participant] > 0) {
                uint256 refundAmount = participantTickets[participant] *
                            TICKET_PRICE;
                participantTickets[participant] = 0; // Обнуляем перед отправкой

                (bool sent,) = payable(participant).call{value: refundAmount}(
                    ""
                );
                require(sent, "Failed to send ETH to participant");
            }
        }

        // Сбрасываем состояние
        delete ticketOwners;
        ticketsSold = 0;
    }
}
