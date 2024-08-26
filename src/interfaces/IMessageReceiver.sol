// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IMessageReceiver {
    function receiveMessage(uint256 chainId, address sender, bytes calldata payload) external;
}
