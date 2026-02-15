// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface RedPackFactory {
    // 创建一个新红包
    function createRedPacket() external;

    // 根据红包ID获取红包合约地址
    function getRedPacketAddress(uint256 redPacketId) external view returns (address);

    // 获取用户拥有的红包列表
    function getOwnedRedPackets(address owner) external view returns (address[] memory);
}
