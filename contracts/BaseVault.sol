// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BaseVault is Ownable {
    struct Lock {
        uint256 amount;
        uint256 start;
        uint256 duration;
        bool withdrawn;
    }

    IERC20 public immutable token;
    uint256 public aprBasisPoints;
    mapping(address => Lock[]) public locks;

    event Locked(address indexed user, uint256 lockId, uint256 amount, uint256 duration);
    event Withdrawn(address indexed user, uint256 lockId, uint256 amount, uint256 interest);

    constructor() {
        token = IERC20(0x26A7D6a8FFd1462D839676732F04EE0D6E41C16e);
        aprBasisPoints = 500; // default 5% APR
    }

    function setApr(uint256 _aprBasisPoints) external onlyOwner {
        aprBasisPoints = _aprBasisPoints;
    }

    function lock(uint256 amount, uint256 durationSeconds) external {
        require(amount > 0, "Amount must be > 0");
        require(durationSeconds >= 60, "Minimum duration: 60 seconds");
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        locks[msg.sender].push(Lock({
            amount: amount,
            start: block.timestamp,
            duration: durationSeconds,
            withdrawn: false
        }));

        emit Locked(msg.sender, locks[msg.sender].length - 1, amount, durationSeconds);
    }

    function locksCount(address user) external view returns (uint256) {
        return locks[user].length;
    }

    function pendingInterest(address user, uint256 lockId) public view returns (uint256) {
        Lock storage lockData = locks[user][lockId];
        if (lockData.withdrawn) return 0;

        uint256 timeLocked = block.timestamp > lockData.start + lockData.duration
            ? lockData.duration
            : block.timestamp - lockData.start;

        uint256 interest = (lockData.amount * aprBasisPoints * timeLocked) / (10000 * 365 days);
        return interest;
    }

    function withdraw(uint256 lockId) external {
        Lock storage lockData = locks[msg.sender][lockId];
        require(!lockData.withdrawn, "Already withdrawn");
        require(block.timestamp >= lockData.start + lockData.duration, "Lock not expired");

        lockData.withdrawn = true;
        uint256 interest = pendingInterest(msg.sender, lockId);
        uint256 total = lockData.amount + interest;

        require(token.transfer(msg.sender, total), "Token transfer failed");
        emit Withdrawn(msg.sender, lockId, lockData.amount, interest);
    }

    function depositRewards(uint256 amt) external onlyOwner {
        require(token.transferFrom(msg.sender, address(this), amt), "Reward deposit failed");
    }
}