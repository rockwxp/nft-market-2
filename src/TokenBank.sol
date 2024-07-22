// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract TokenBank {
    IERC20 public token;
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address _tokenAddress) {
        token = ERC20(_tokenAddress);
    }

    function deposit(uint256 amount) public {
        require(amount > 0, "amount should more than 0");
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "transfer faild"
        );

        balances[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "transfer faild");
        emit Withdraw(msg.sender, amount);
    }

    function permitDeposit(
        address owner,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 调用ERC20Permit的permit方法进行授权
        ERC20Permit(address(token)).permit(
            owner,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        // 存款逻辑
        require(
            token.transferFrom(owner, address(this), value),
            "Transfer failed"
        );
        balances[owner] += value;
        // 触发存款事件
        emit Deposit(owner, value);
    }
}
