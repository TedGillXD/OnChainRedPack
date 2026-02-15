// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

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

    function claim(bytes32[] calldata whitelistProof, bytes32[] calldata blacklistProof) external override {
        _verifyClaim(msg.sender, whitelistProof, blacklistProof);
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

    function isRedPacketActive() external view returns (bool) {
        return block.timestamp >= startTime && block.timestamp <= endTime && remainShares > 0;
    }
}
