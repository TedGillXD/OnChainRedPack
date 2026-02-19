// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IRedPacket} from "../interfaces/IRedPacket.sol";

import {RedPacketStorage} from "./RedPacketStorage.sol";

abstract contract RedPacketBase is RedPacketStorage, IRedPacket {
    uint256 constant VERIFY_WHITELIST = 1 << uint256(VerifyType.WHITELIST);
    uint256 constant VERIFY_BLACKLIST = 1 << uint256(VerifyType.BLACKLIST);
    uint256 constant VERIFY_HAS_ENOUGH_BALANCE = 1 << uint256(VerifyType.HAS_ENOUGH_BALANCE);

    event RedPacketInitialized(
        address indexed redPacketAddress,
        address indexed creator,
        address token,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime,
        uint32 totalShares,
        RedPacketType packetType,
        uint8 verifyFlags
    );
    event RedPacketClaimed(address indexed redPacketAddress, address indexed claimer, uint256 amount);
    event RedPacketRefunded(address indexed redPacketAddress, address indexed creator, uint256 amount);
    event WhitelistUpdated(address indexed redPacketAddress, address indexed user, bool allowed);
    event BlacklistUpdated(address indexed redPacketAddress, address indexed user, bool blocked);

    function _initialize(RedPacketInitializer memory initializer) internal {
        // 基础参数校验
        require(initializer.startTime <= type(uint40).max, "startTime overflow");
        require(initializer.endTime <= type(uint40).max, "endTime overflow");
        require(initializer.startTime < initializer.endTime, "Invalid time range");
        require(initializer.totalShares > 0, "Total shares must be greater than 0");
        require(initializer.token != address(this), "Token address cannot be the same as contract address");
        require(initializer.endTime > block.timestamp, "End time must be in the future");
        if (initializer.token == address(0)) {
            require(msg.value != 0, "Total amount must be sent when creating a native token red packet");
            initializer.totalAmount = msg.value;
        } else {
            require(msg.value == 0, "ERC20 red packet should not include native token");
            require(initializer.totalAmount > 0, "TotalAmount cannot be zero for ERC20 red packet");
        }
        require(initializer.totalAmount > 0, "Total amount must be greater than 0");
        require(initializer.totalAmount >= initializer.totalShares, "Total amount must be at least equal to total shares");

        // 验证参数校验
        if ((initializer.verifyFlags & VERIFY_HAS_ENOUGH_BALANCE) != 0) {
            require(initializer.minBalance > 0, "Min balance must be greater than 0 when balance verification is enabled");
        }

        // 初始化状态
        creator = initializer.creator;
        token = initializer.token;
        totalAmount = initializer.totalAmount;
        remainAmount = initializer.totalAmount;
        totalShares = initializer.totalShares;
        remainShares = initializer.totalShares;
        startTime = uint40(initializer.startTime);
        endTime = uint40(initializer.endTime);
        packetType = initializer.redPacketType;
        verifyFlags = initializer.verifyFlags;
        minBalance = initializer.minBalance;
    }

    function _verifyWhitelist(address claimer) internal view returns (bool) {
        return whitelist[claimer];
    }

    function _verifyBlacklist(address claimer) internal view returns (bool) {
        return blacklist[claimer];
    }

    function _verifyHasEnoughBalance(address claimer) internal view returns (bool) {
        return claimer.balance >= minBalance;
    }

    function _verifyClaim(address claimer) internal view {
        if ((verifyFlags & VERIFY_WHITELIST) != 0) {
            require(_verifyWhitelist(claimer), "Not in whitelist");
        }
        if ((verifyFlags & VERIFY_BLACKLIST) != 0) {
            require(!_verifyBlacklist(claimer), "In blacklist");
        }
        if ((verifyFlags & VERIFY_HAS_ENOUGH_BALANCE) != 0) {
            require(_verifyHasEnoughBalance(claimer), "Not enough balance");
        }
        require(block.timestamp >= startTime, "Red packet not started");
        require(block.timestamp <= endTime, "Red packet expired");
        require(remainShares > 0, "No shares left");
    }

    function getWhitelistStatus(address user) external view override returns (bool) {
        return whitelist[user];
    }

    function getBlacklistStatus(address user) external view override returns (bool) {
        return blacklist[user];
    }
}
