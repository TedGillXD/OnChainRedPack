// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {RedPacketBase} from "./RedPacketBase.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {TokenTransferLib} from "../libraries/TokenTransferLib.sol";

contract RedPacket is RedPacketBase, Initializable, OwnableUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(RedPacketInitializer memory initData) external payable override initializer {
        __Ownable_init(initData.creator);
        _initialize(initData);
        emit RedPacketInitialized(
            address(this),
            initData.creator,
            initData.token,
            totalAmount,
            initData.startTime,
            initData.endTime,
            initData.totalShares,
            initData.redPacketType,
            initData.verifyFlags
        );
    }

    function claim() external override {
        _verifyClaim(msg.sender);
        require(claimed[msg.sender] == false, "Already claimed");

        uint256 amountToClaim;
        if (remainShares == 1) {
            // 最后一份，领取剩余的全部金额
            amountToClaim = remainAmount;
        } else if (packetType == RedPacketType.NORMAL) {
            // 普通红包，每份金额相同
            amountToClaim = totalAmount / totalShares;
        } else {
            uint256 avg = remainAmount / remainShares;

            // 1) 先给一个围绕均值的区间（例如 ±50%）
            uint256 minCanTake = avg / 2;
            if (minCanTake < 1) minCanTake = 1;

            uint256 maxCanTake = avg + (avg / 2);

            // 2) 仍要满足硬约束：至少给后续每份留 1
            uint256 hardMax = remainAmount - (remainShares - 1);
            if (maxCanTake > hardMax) {
                maxCanTake = hardMax;
            }
            if (minCanTake > maxCanTake) {
                minCanTake = maxCanTake;
            }

            // 3) 用“中心偏置”而不是均匀分布，减少极端值
            uint256 span = maxCanTake - minCanTake + 1;
            uint256 r1 = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, remainAmount, remainShares, uint256(1))));
            uint256 r2 = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, remainAmount, remainShares, uint256(2))));
            uint256 centered = ((r1 % span) + (r2 % span)) / 2; // 更偏向中间
            amountToClaim = minCanTake + centered;
        }

        // 更新状态
        claimed[msg.sender] = true;
        claimAmount[msg.sender] = amountToClaim;
        remainAmount -= amountToClaim;
        remainShares -= 1;

        // 发放红包
        TokenTransferLib.safeTransfer(token, msg.sender, amountToClaim);
        emit RedPacketClaimed(address(this), msg.sender, amountToClaim);
    }

    function refund() external override onlyOwner {
        require(block.timestamp > endTime, "Red packet not expired");
        uint256 refundAmount = remainAmount;
        require(refundAmount > 0, "refundAmount should greater than 0");
        remainAmount = 0;
        remainShares = 0;
        TokenTransferLib.safeTransfer(token, owner(), refundAmount);
        emit RedPacketRefunded(address(this), owner(), refundAmount);
    }

    function setWhitelist(address user, bool allowed) external override onlyOwner {
        _setWhitelist(user, allowed);
        emit WhitelistUpdated(address(this), user, allowed);
    }

    function setWhitelistBatch(address[] calldata users, bool allowed) external override onlyOwner {
        require(users.length > 0, "empty users");
        for (uint256 i = 0; i < users.length; i++) {
            _setWhitelist(users[i], allowed);
            emit WhitelistUpdated(address(this), users[i], allowed);
        }
    }

    function setBlacklist(address user, bool blocked) external override onlyOwner {
        _setBlacklist(user, blocked);
        emit BlacklistUpdated(address(this), user, blocked);
    }

    function setBlacklistBatch(address[] calldata users, bool blocked) external override onlyOwner {
        require(users.length > 0, "empty users");
        for (uint256 i = 0; i < users.length; i++) {
            _setBlacklist(users[i], blocked);
            emit BlacklistUpdated(address(this), users[i], blocked);
        }
    }

    // 获取白名单和黑名单列表，主要用于前端展示，不要在链上频繁调用，尤其是当名单较长时
    function getWhitelist() external view override returns (address[] memory) {
        return whitelistUsers;
    }

    // 同上，获取黑名单列表
    function getBlacklist() external view override returns (address[] memory) {
        return blacklistUsers;
    }

    function isRedPacketActive() external view returns (bool) {
        return block.timestamp >= startTime && block.timestamp <= endTime && remainShares > 0;
    }

    function _setWhitelist(address user, bool allowed) internal {
        if (allowed) {
            if (!whitelist[user]) {
                whitelist[user] = true;
                whitelistUsers.push(user);
                whitelistIndexPlusOne[user] = whitelistUsers.length;
            }
        } else if (whitelist[user]) {
            whitelist[user] = false;
            _removeWhitelistUser(user);
        }
    }

    function _setBlacklist(address user, bool blocked) internal {
        if (blocked) {
            if (!blacklist[user]) {
                blacklist[user] = true;
                blacklistUsers.push(user);
                blacklistIndexPlusOne[user] = blacklistUsers.length;
            }
        } else if (blacklist[user]) {
            blacklist[user] = false;
            _removeBlacklistUser(user);
        }
    }

    function _removeWhitelistUser(address user) internal {
        uint256 indexPlusOne = whitelistIndexPlusOne[user];
        if (indexPlusOne == 0) return;

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = whitelistUsers.length - 1;
        if (index != lastIndex) {
            address lastUser = whitelistUsers[lastIndex];
            whitelistUsers[index] = lastUser;
            whitelistIndexPlusOne[lastUser] = index + 1;
        }
        whitelistUsers.pop();
        whitelistIndexPlusOne[user] = 0;
    }

    function _removeBlacklistUser(address user) internal {
        uint256 indexPlusOne = blacklistIndexPlusOne[user];
        if (indexPlusOne == 0) return;

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = blacklistUsers.length - 1;
        if (index != lastIndex) {
            address lastUser = blacklistUsers[lastIndex];
            blacklistUsers[index] = lastUser;
            blacklistIndexPlusOne[lastUser] = index + 1;
        }
        blacklistUsers.pop();
        blacklistIndexPlusOne[user] = 0;
    }
}
