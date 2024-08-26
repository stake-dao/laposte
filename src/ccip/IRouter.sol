// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Client} from "src/ccip/Client.sol";

interface IRouter {
    function isChainSupported(uint64 chainId) external view returns (bool);
    function getFee(uint64 chainId, Client.EVM2AnyMessage calldata message) external view returns (uint256);
    function ccipSend(uint64 chainId, Client.EVM2AnyMessage calldata message) external payable returns (bytes32);
    function ccipReceive(Client.Any2EVMMessage calldata message) external;
}
