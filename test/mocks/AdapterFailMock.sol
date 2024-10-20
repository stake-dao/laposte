// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

contract AdapterFailMock {
    function sendMessage(address, uint256, uint256, bytes calldata) external payable returns (bytes32) {
        revert("Fail");
    }
}
