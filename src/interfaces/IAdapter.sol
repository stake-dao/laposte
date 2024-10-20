// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IAdapter {
    function sendMessage(address adapter, uint256 executionGasLimit, uint256 destinationChainId, bytes calldata message)
        external
        payable
        returns (uint256);
}
