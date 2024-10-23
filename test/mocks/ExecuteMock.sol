// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExecuteMock {
    event HelloWorld(uint256 param);

    function receiveMessage(uint256 chainId, address, bytes calldata payload) external {
        (address to, address token) = abi.decode(payload, (address, address));
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(to, balance);

        emit HelloWorld(chainId);
    }
}
