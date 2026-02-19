// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library TokenTransferLib {
    using SafeERC20 for IERC20;

    function safeTransfer(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            // 原生币转账
            (bool success, ) = to.call{value: amount}("");
            require(success, "Native token transfer failed");
        } else {
            // ERC20 代币转账
            IERC20(token).safeTransfer(to, amount);
        }
    }
}
