// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SingleLottery} from "../src/SingleLottery.sol";

contract LotteryDeployScript is Script {
    function run() public {
        // Считываем приватный ключ из переменной окружения
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Начинаем трансляцию транзакций
        vm.startBroadcast(deployerPrivateKey);

        // Деплоим контракт с заданными параметрами
        // 0.01 ETH цена билета и 100 билетов всего
        SingleLottery lottery = new SingleLottery(0.01 ether, 100);

        // Выводим адрес контракта для справки
        console.log("Lottery deployed at:", address(lottery));

        // Завершаем трансляцию
        vm.stopBroadcast();
    }
}