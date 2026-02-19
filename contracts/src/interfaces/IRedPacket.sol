// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IRedPacketEnumDef {
    // 红包类型：普通红包（每份金额相同）和随机红包（每份金额随机）
    enum RedPacketType {
        NORMAL,
        RANDOM
    }

    // 验证类型：无验证、白名单、黑名单、余额验证（检查领取者是否有足够的原生代币）
    // 只添加，不修改顺序！
    enum VerifyType {
        NONE,
        WHITELIST,
        BLACKLIST,
        HAS_ENOUGH_BALANCE
    }
}

interface IRedPacket is IRedPacketEnumDef {
    struct RedPacketInitializer {
        address creator;        // 红包创建者地址
        address token;          // 表示红包发放的代币地址，address(0)代表原生币
        uint256 totalAmount;    // 表示红包的总金额，单位为最小单位（如wei），对于ERC20代币也是如此
        uint256 startTime;      // 表示红包的开始时间，单位为Unix时间戳
        uint256 endTime;        // 表示红包的结束时间，单位为Unix时间戳

        uint32 totalShares;    // 表示红包的总份数，即红包将被分成多少份

        RedPacketType redPacketType;
        uint8 verifyFlags;
        uint256 minBalance;       // 仅当verifyFlags包含HAS_ENOUGH_BALANCE时有效，表示领取红包所需的最小余额，单位为最小单位（如wei）
    }

    // 创建红包
    function initialize(RedPacketInitializer memory initializer) external payable;

    // 领取红包
    function claim() external;

    // 退款，只有红包创建者可以调用，且只能在红包结束后调用
    function refund() external;

    // 设置白名单地址
    function setWhitelist(address user, bool allowed) external;

    // 批量设置白名单地址
    function setWhitelistBatch(address[] calldata users, bool allowed) external;

    // 设置黑名单地址
    function setBlacklist(address user, bool blocked) external;

    // 批量设置黑名单地址
    function setBlacklistBatch(address[] calldata users, bool blocked) external;

    // 查询地址是否在白名单中
    function getWhitelistStatus(address user) external view returns (bool);

    // 查询地址是否在黑名单中
    function getBlacklistStatus(address user) external view returns (bool);

    // 获取红包白名单地址列表
    function getWhitelist() external view returns (address[] memory);

    // 获取红包黑名单地址列表
    function getBlacklist() external view returns (address[] memory);
}
