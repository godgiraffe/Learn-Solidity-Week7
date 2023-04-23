// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IWETH9 {
    // Deposit => 將與 msg.value 量相同的 erc20 token 轉給 user
    function deposit() external payable;
    // 將與 _amount 數量的 ethers 從合約中轉給 user，並 burn 掉對應數量的 token
    function withdraw(uint256 _amount) external;
    // 將與 msg.value 量的 erc20 token 轉給 user
    receive() external payable;

    event  Deposit(address indexed dst, uint _amount);
    event  Withdrawal(address indexed src, uint _amount);
}