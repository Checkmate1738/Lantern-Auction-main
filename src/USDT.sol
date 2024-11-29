//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract USDT is ERC20, Ownable {

    uint256 private accumulatedFee;
    uint256 constant internal profit = 1000000;
    uint256 private accumulatedProfit;

    event Deposit(address indexed to, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);

    constructor () ERC20("US Dollar Tether","USDT") Ownable(msg.sender) {}

    function deposit() payable public {
        uint256 amount = 1 ether;
        require(msg.value >= amount,"Below minimum amount");
        uint256 value = msg.value - 1 gwei;
        accumulatedFee += (1 gwei - profit);
        accumulatedProfit += profit;
        _mint(msg.sender, value);
        emit Deposit(msg.sender, amount);
    }

    function withdraw() payable public {
        require(balanceOf(msg.sender) > 0,"No balance for withdraw");
        uint256 amount = balanceOf(msg.sender) + ( 1 gwei - 1000 );
        require(address(this).balance >= amount);
        _burn(msg.sender, balanceOf(msg.sender));
        (bool success, ) = msg.sender.call{value:amount}("");
        require(success,"Transfer unsuccessful");
        emit Withdraw(msg.sender, amount);
    }

    function WithdrawFee() payable public onlyOwner {
        uint256 amount = accumulatedProfit;
        accumulatedProfit = 0;
        (bool success, ) = msg.sender.call{value:amount}("");
        require(success,"Transfer unsuccessful");
        emit Withdraw(msg.sender, amount);
    }

}