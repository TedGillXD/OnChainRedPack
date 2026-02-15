// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IRedPacketEnumDef} from "../interfaces/IRedPacket.sol";

contract RedPacketStorage is IRedPacketEnumDef {
    // slot 0
    address creator; // 红包创建者和拥有者
    uint40 startTime; // 红包开始时间，单位为 Unix 时间戳
    uint40 endTime; // 红包结束时间，单位为 Unix 时间戳

    // slot 1
    address token; // 红包发放的 ERC20 代币地址
    RedPacketType packetType; // 红包类型：普通红包或随机红包
    uint8 verifyFlags; // 验证标志位，使用位运算表示不同的验证方式
    uint32 totalShares; // 红包总份数
    uint32 remainShares; // 红包剩余份数

    // slot 2-6
    uint256 totalAmount; // 红包总金额
    uint256 remainAmount; // 红包剩余金额
    uint256 minBalance; // 最小余额要求，仅当 verifyFlags 包含 HAS_ENOUGH_BALANCE 时有效
    bytes32 whitelistRoot; // 白名单 Merkle Root，仅当 verifyFlags 包含 WHITELIST 时有效
    bytes32 blacklistRoot; // 黑名单 Merkle Root，仅当 verifyFlags 包含 BLACKLIST 时有效

    mapping(address => uint256) claimAmount; // 记录每个地址领取金额
    mapping(address => bool) claimed; // 记录每个地址是否已领取

    uint256[50] private _gap; // 预留存储空间，允许未来添加新的状态变量而不影响现有布局
}
