// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IRedPackFactory} from "../interfaces/IRedPackFactory.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IRedPacket} from "../interfaces/IRedPacket.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract RedPackFactory is Initializable, OwnableUpgradeable, IRedPackFactory {
    using SafeERC20 for IERC20;

    address public beacon; // 预留一个 beacon 地址，未来可以用来部署基于 beacon proxy 的红包合约
    uint256 nextRedPacketId; // 递增的红包ID，用于生成唯一的红包地址

    mapping(uint256 => address) public redPacketAddresses; // 红包ID到红包合约地址的映射
    mapping(address => uint256[]) public ownerToRedPacketIds; // 红包拥有者到红包ID列表的映射

    mapping(address => bool) public tokenWhitelist; // 预设的代币白名单

    event TokenWhitelistUpdated(address indexed token, bool isEnabled);
    event RedPacketCreated(
        uint256 indexed packetId,
        address indexed creator,
        address packetAddress,
        address token,
        uint256 totalAmount,
        uint256 totalShares
    );

    // 初始化函数，设置初始拥有者
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _beacon) external initializer {
        require(initialOwner != address(0), "invalid owner");
        require(_beacon != address(0), "invalid beacon");
        __Ownable_init(initialOwner);
        require(UpgradeableBeacon(_beacon).owner() == address(this), "factory is not beacon owner");
        tokenWhitelist[address(0)] = true; // 默认允许原生币
        beacon = _beacon;
        nextRedPacketId = 1; // 从1开始，0可以用作无效ID
    }

    // IRedPackFactory 接口实现
    function createRedPacket(IRedPacket.RedPacketInitializer memory initData) external override payable returns (uint256 packetId, address packet) {
        // 这里应该部署一个新的 RedPacket 合约实例，并记录它的地址
        if (initData.token != address(0)) {
            require(msg.value == 0, "ERC20 red packet should not include native token");
            require(initData.totalAmount != 0, "ERC20 red packet with 0 token amount!");
        } else {
            require(msg.value > 0, "native red packet should include native token");
        }
        require(beacon != address(0), "beacon not set");
        require(initData.creator == msg.sender, "creator mismatch");
        require(tokenWhitelist[initData.token], "token not whitelisted");

        // 构造 initialize calldata，部署时一次性初始化
        bytes memory initCalldata = abi.encodeCall(IRedPacket.initialize, (initData));

        // 创建 BeaconProxy 红包实例（原生币红包场景要透传 msg.value）
        BeaconProxy proxy = new BeaconProxy{value: msg.value}(beacon, initCalldata);
        packet = address(proxy);

        // ERC20 红包：由 Factory 拉取并转入新创建的红包实例
        if (initData.token != address(0)) {
            IERC20(initData.token).safeTransferFrom(msg.sender, packet, initData.totalAmount);
        }

        // 记录索引
        packetId = nextRedPacketId++;
        redPacketAddresses[packetId] = packet;
        ownerToRedPacketIds[msg.sender].push(packetId);

        uint256 tokenAmount = initData.token == address(0) ? msg.value : uint256(initData.totalAmount); // 只有原生币红包才会有 msg.value，ERC20红包则金额来自 initData.totalAmount
        emit RedPacketCreated(
            packetId,
            msg.sender,
            packet,
            initData.token,
            tokenAmount,
            initData.totalShares
        );

        return (packetId, packet);
    }

    function getRedPacketAddress(uint256 redPacketId) external view override returns (address) {
        return redPacketAddresses[redPacketId];
    }

    function getOwnedRedPackets(address owner) external view override returns (address[] memory) {
        uint256[] memory ids = ownerToRedPacketIds[owner];
        address[] memory addresses = new address[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            addresses[i] = redPacketAddresses[ids[i]];
        }
        return addresses;
    }

    // Beacon地址管理函数，只有拥有者可以调用
    function upgradeBeaconTo(address newImplementation) external onlyOwner {
        require(newImplementation != address(0), "Invalid beacon implementation address");
        require(UpgradeableBeacon(beacon).owner() == address(this), "factory is not beacon owner");
        UpgradeableBeacon(beacon).upgradeTo(newImplementation);
    }

    function getBeacon() external view override returns (address) {
        return beacon;
    }

    function updateTokenWhitelist(address token, bool isEnable) external onlyOwner {
        tokenWhitelist[token] = isEnable;
        emit TokenWhitelistUpdated(token, isEnable);
    }
}
