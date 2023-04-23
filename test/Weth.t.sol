// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Weth} from "../src/Weth.sol";

contract WethTest is Test {
    uint256 public totalSupply; // 該 ERC20 token 的總供應量
    mapping(address => uint256) public balanceOf; // 查詢 address 所持有的 Token 數量
    mapping(address => mapping(address => uint256)) public allowance; // 查詢 某 token owner 允許 某地址，花他多少 erc20 token，還剩多少扣打
    string public name = "Wrap Ether"; // token name
    string public symbol = "WETH"; // token symbol
    uint8 public decimals = 18; // 小數點後有 18 個零

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event Deposit(address indexed from, uint _amount);
    event Withdrawal(address indexed to, uint _amount);

    Weth instance;
    address user1;
    address user2;
    address user3;

    function setUp() public {
        user1 = address(1);
        user2 = address(2);
        user3 = address(3);
        instance = new Weth();
    }

    // deposit 應該將與 msg.value 相等的 ERC20 token mint 給 user
    function testDepositTokenToUser(uint _amount) public {
        /**
        1. 先讓 user 有錢
        2. 讓 user 去 deposit
        3. 檢查 user 的 erc20 token 有沒有跟剛剛執行 deposit 的 msg.value 相同
       */
        // 如果隨機產生的 _amount < 0.1 ether，就重新產生
        vm.assume(_amount > 0.1 ether);
        vm.startPrank(user1);
        vm.deal(user1, _amount);
        instance.deposit{value: _amount}();
        uint user1_erc20_balance = instance.balanceOf(user1);
        vm.stopPrank();
        assertEq(_amount, user1_erc20_balance); // 檢查執行 deposit 的 msg.value 是否有與 user 拿到的 erc20 token 相同
    }

    // deposit 應該將 msg.value 的 ether 轉入合約
    function testDepositEtherIntoContract(uint _amouont) public {
        /**
        1. 先紀錄 contract 內有多少 ether
        2. 執行 deposit
        3. 確認 contract 的 ether 的增加值，是否有等於 執行 deposit 的 msg.value
       */
        uint orgin_contract_balance = address(instance).balance;
        uint after_deposit_contract_balance = 0;
        console.log("origin_contract_balance", address(instance).balance);
        vm.deal(user1, _amouont);
        vm.startPrank(user1);

        instance.deposit{value: _amouont}();
        after_deposit_contract_balance = address(instance).balance;
        assertEq(
            after_deposit_contract_balance,
            orgin_contract_balance + _amouont
        );
        vm.stopPrank();
    }

    // deposit 應該要 emit Deposit event
    function testDepositEvent(uint _amount) public {
        // function testDepositEvent() public {
        /**
        1. 先 deposit
        2. 觸發 event
        3. 檢查 event
       */
        vm.startPrank(user1);
        vm.deal(user1, _amount);
        vm.expectEmit(true, false, false, true);
        emit Deposit(user1, _amount);
        instance.deposit{value: _amount}();
        vm.stopPrank();
    }

    // withdraw 應該要 burn 掉與 input parameters 一樣的 erc20 token
    function testWithDrawShouldBurnERC20Token(
        uint _amount,
        uint _depositNum
    ) public {
        /**
        1. 取得 erc20 token 目前的總數
        2. 如果總數為零，那要先去 deposit，並且 deposit 的數量 > _amount
        2. 讓 user 有錢
        3. 去 withdraw(_amount)
        4. 檢查 erc20 token 的總數有沒有減少 _amount 個
       */
        vm.assume(_amount < _depositNum);
        uint originWethTokenTotalSupply = instance.totalSupply();
        vm.startPrank(user1);
        if (originWethTokenTotalSupply == 0) {
            vm.deal(user1, _depositNum);
            instance.deposit{value: _depositNum}();
        }
        originWethTokenTotalSupply = instance.totalSupply();
        instance.withdraw(_amount);
        emit Transfer(user1, address(0), _amount);
        assertEq(originWethTokenTotalSupply, instance.totalSupply() + _amount);
        vm.stopPrank();
    }

    // withdraw 應該將 burn 掉的 erc20 換成 ether 轉給 user
    function testWithdrawShouldTransferEtherToUser(
        uint _depositNum,
        uint _withdrawNum
    ) public {
        /**
        1. 先讓 user 有錢
        2. 讓 user 去 deposit(_depositNum)
        2. 取得 user withdraw 前的 balance & weth withraw 前的 totalSupply
        3. 去 withdraw(_amount)
        4. 取得 user withdraw 後的 balance & weth withraw 後的 totalSupply
        5. withraw 前的 totalSupply  - withraw 後的 totalSupply = user withraw 後的 balance - user withraw 前的 balance
       */

        vm.assume(_withdrawNum < _depositNum);

        uint beforeWithrawUserBalance = 0;
        uint beforeWithrawTotalSupply = 0;
        uint afterWithrawTotalSupply = 0;
        uint afterWithrawUserBalance = 0;

        vm.startPrank(user1);
        vm.deal(user1, _depositNum);
        instance.deposit{value: _depositNum}();
        beforeWithrawUserBalance = user1.balance;
        beforeWithrawTotalSupply = instance.totalSupply();
        instance.withdraw(_withdrawNum);

        afterWithrawTotalSupply = instance.totalSupply();
        afterWithrawUserBalance = user1.balance;

        assertEq(
            beforeWithrawTotalSupply - afterWithrawTotalSupply,
            afterWithrawUserBalance - beforeWithrawUserBalance
        );
        vm.stopPrank();
    }

    // withdraw 應該要 emit Withdraw event
    function testWithdrawShouldEmitWithrawEvent(
        uint _amount,
        uint _depositNum
    ) public {
        /**
        1. 先讓 user 有錢
        2. 讓 user 去 deposit(_depositNum)
        3. 去 withdraw(_amount)
        4. 檢查有沒有 emit Withdraw event
       */

        vm.assume(_depositNum < _amount);

        vm.startPrank(user1);
        vm.deal(user1, _amount);
        instance.deposit{value: _depositNum}();
        vm.expectEmit(true, false, false, true);
        emit Transfer(user1, address(0), _depositNum);
        instance.withdraw(_depositNum);
        vm.stopPrank();
    }

    // transfer 應該要將 erc20 token 轉給別人
    function testTransferShouldSendTokenToUser(
        uint _user1Balance,
        uint _depositNum,
        uint _transferNum
    ) public {
        // function testTransferShouldSendTokenToUser() public {
        /**
        1. 先讓 user 有錢
        2. 讓 user 去 deposit, 取得 erc20 token
        3. user1 transfer erc20 token to user 2
        4. 檢查 user 1 的 erc20 token 減少數量有無正確
        5. 檢查 user 2 的 erc20 token 增加數量有無正確
       */
        vm.assume(_user1Balance >= _depositNum);
        vm.assume(_depositNum >= _transferNum);

        vm.deal(user1, _user1Balance);
        vm.startPrank(user1);
        instance.deposit{value: _depositNum}();
        uint beforeTransferUser1ERC20Num = instance.balanceOf(user1);
        uint beforeTransferUser2ERC20Num = instance.balanceOf(user2);
        bool success = instance.transfer(user2, _transferNum);
        assertEq(success, true);
        uint afterTransferUser1ERC20Num = instance.balanceOf(user1);
        uint afterTransferUser2ERC20Num = instance.balanceOf(user2);
        assertEq(
            afterTransferUser1ERC20Num,
            beforeTransferUser1ERC20Num - _transferNum
        );
        assertEq(
            afterTransferUser2ERC20Num,
            beforeTransferUser2ERC20Num + _transferNum
        );
        vm.stopPrank();
    }

    // approve 應該要給他人 allowance
    function testApproveCanBeOtherUser(uint _amount) public {
        /**
        1. user1 approve user2 使用數量為 _amount 的 erc20 token
        2. 檢查 allowance[user1][user2] 的值是否 > 0 && 是否 = _amount
         */
        vm.assume(_amount > 0);
        vm.startPrank(user1);
        instance.approve(user2, _amount);
        console.log("amount", _amount);
        console.log("B", instance.allowance(user1, user2));
        assertGt(instance.allowance(user1, user2), 0);
        assertEq(instance.allowance(user1, user2), _amount);
        vm.stopPrank();
    }

    // transferFrom 應該要可以使用他人的 allowance
    // transferFrom 後應該要減除用完的 allowance
    function testShouldTransferFromUsingAllowance(uint _amount, uint _transferNum) public {
        /**
        1. user1 deposit 數量為 _amount 的 ether
        2. user1 approve user2 使用數量為 _amount 的 erc20 token
        3. user2 去使用 transferFrom，傳送數量為 _transferNum 的 erc20 token，給 user 3
        4. 檢查 user1 允許給 user2 使用的 allowance 減少的數量是否 == _transferNum
        54. 檢查 user3 增加的 erc20 token 數量是否 == _transferNum

        其它 case：
          使用 > allowance 的數量去測
         */
        vm.assume(_amount > 0);
        vm.assume(_transferNum > 0);
        vm.assume(_amount > _transferNum);

        vm.startPrank(user1);
        vm.deal(user1, _amount);
        instance.deposit{value: _amount}();
        instance.approve(user2, _amount);
        vm.stopPrank();

        uint beforeTransferFromUser1Allowance = instance.allowance(user1, user2);
        uint beforeTransferFromUser3Token = instance.balanceOf(user3);
        vm.startPrank(user2);
        instance.transferFrom(user1, user3, _transferNum);
        uint afterTranserFromUser1Allowance = instance.allowance(user1, user2);
        uint afterTransferFromUser3Token = instance.balanceOf(user3);

        assertEq(beforeTransferFromUser1Allowance - afterTranserFromUser1Allowance, _transferNum);
        assertEq(afterTransferFromUser3Token - beforeTransferFromUser3Token, _transferNum);
    }
    // 其他可以 test case 可以自己想，看完整程度給分
}
