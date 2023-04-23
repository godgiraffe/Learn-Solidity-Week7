// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.9 <0.9.0;

import "./IWeth.sol";
import "./IERC20.sol";

contract Weth is IWETH9, IERC20 {
    uint256 public totalSupply; // 該 ERC20 token 的總供應量
    mapping(address => uint256) public balanceOf; // 查詢 address 所持有的 Token 數量
    mapping(address => mapping(address => uint256)) public allowance; // 查詢 某 token owner 允許 某地址，花他多少 erc20 token，還剩多少扣打
    string public name = "Wrap Ether"; // token name
    string public symbol = "WETH"; // token symbol
    uint8 public decimals = 18; // 小數點後有 18 個零

    // erc20 的 token owner，可以調用 transfer 來轉移他的 erc20 token.
    function transfer(
        address to,
        uint256 amount
    ) external returns (bool success) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // erc20 的 token owner，可以批准某個地址，來花費他的多少扣打的 erc20 token
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool success) {
        allowance[msg.sender][spender] = amount; // msg.sender 允許 spender 花費 amount 個 ERC20 token
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // 被 token owner 允許的那個人，可以調用 transferFrom 來轉移 token owner 的 erc20 token
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool success) {
        require(
            allowance[from][msg.sender] >= amount,
            "insufficient allowance"
        );
        // 在 solidity 0.8 中，overflow & underflow 都會使程式出錯
        // 所以，如果 msg.sender 沒有被允許使用 erc20 token 的話，這行就會執行失敗
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function mint(uint256 amount) external {
        uint256 changeAmount = amount;
        balanceOf[msg.sender] += changeAmount;
        totalSupply += changeAmount;
        emit Transfer(address(0), msg.sender, changeAmount);
    }

    function burn(uint256 amount) external {
        uint256 changeAmount = amount;
        balanceOf[msg.sender] -= changeAmount;
        totalSupply -= changeAmount;
        emit Transfer(msg.sender, address(0), changeAmount);
    }

    // Deposit => 將與 msg.value 量相同的 erc20 token 轉給 user
    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // Withdraw => 將與 _amount 數量的 ethers 從合約中轉給 user，並 burn 掉對應數量的 token
    function withdraw(uint256 _amount) external {
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Ether transfer failed.");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        emit Withdrawal(msg.sender, _amount);
        emit Transfer(msg.sender, address(0), _amount);
    }

    // Receive => 將與 msg.value 量的 erc20 token 轉給 user
    receive() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
        emit Transfer(address(0), msg.sender, msg.value);
    }
}
