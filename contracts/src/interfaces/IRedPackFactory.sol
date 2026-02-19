// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IRedPacket} from "../interfaces/IRedPacket.sol";

interface IRedPackFactory {
    // 创建一个新红包
    function createRedPacket(IRedPacket.RedPacketInitializer memory initializer) external payable returns (uint256 packetId, address packet);

    // 根据红包ID获取红包合约地址
    function getRedPacketAddress(uint256 redPacketId) external view returns (address);

    // 获取用户拥有的红包列表
    function getOwnedRedPackets(address owner) external view returns (address[] memory);

    function upgradeBeaconTo(address newImplementation) external;

    function getBeacon() external view returns (address);

    function updateTokenWhitelist(address token, bool isEnable) external;
}
