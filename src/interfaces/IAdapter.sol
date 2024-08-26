// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IAdapter {
    struct Token {
        address tokenAddress;
        uint256 amount;
    }

    struct TokenMetadata {
        string name;
        string symbol;
        uint8 decimals;
    }

    struct Message {
        uint256 destinationChainId;
        address to;
        address sender;
        Token token;
        TokenMetadata tokenMetadata;
        bytes payload;
        uint256 nonce;
    }

    function sendMessage(address adapter, uint256 executionGasLimit, uint256 destinationChainId, bytes calldata message)
        external
        payable
        returns (uint256);

    function receiveMessage(uint256 chainId, bytes calldata payload) external;

    function getSender() external view returns (address);
}
