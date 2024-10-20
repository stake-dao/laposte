// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IAdapter} from "src/interfaces/IAdapter.sol";
import {ILaPoste} from "src/interfaces/ILaPoste.sol";

contract AdapterMock {
    address public laPoste;

    constructor(address _laPoste) {
        laPoste = _laPoste;
    }

    function sendMessage(address, uint256, uint256, bytes calldata) external payable returns (bytes32) {
        return bytes32("Success");
    }

    function ccipReceive(uint256 sourceChainId, ILaPoste.Message memory message) external {
        bytes memory payload = abi.encode(message);
        ILaPoste(laPoste).receiveMessage({chainId: sourceChainId, payload: payload});
    }
}
