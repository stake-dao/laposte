// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "src/ccip/IRouter.sol";
import "src/libraries/Chains.sol";
import "src/interfaces/IAdapter.sol";

import "src/interfaces/IERC165.sol";
import "src/interfaces/IAny2EVMMessageReceiver.sol";

/// @title Adapter
/// @notice Adapter for CCIP.
/// @dev This contract handles cross-chain message sending and receiving using Chainlink CCIP.
contract Adapter is IAny2EVMMessageReceiver, IERC165 {
    using SafeCast for uint256;

    /// @notice The address of the LaPoste contract
    address public immutable laPoste;

    /// @notice The base gas limit for cross-chain transactions
    uint256 public immutable BASE_GAS_LIMIT;

    /// @notice The CCIP router contract
    IRouter public immutable router;

    /// @notice Thrown when the caller is not the router
    error OnlyRouter();
    /// @notice Thrown when the caller is not LaPoste
    error OnlyLaPoste();
    /// @notice Thrown when the sender is invalid
    error InvalidSender();
    /// @notice Thrown when the chain ID is invalid
    error InvalidChainId();
    /// @notice Thrown when the message is invalid
    error InvalidMessage();
    /// @notice Thrown when the fee is insufficient
    error NotEnoughFee();
    /// @notice Thrown when a zero address is provided
    error ZeroAddress();
    /// @notice Thrown when the destination chain ID is the same as the source chain ID
    error SameChain();

    /// @notice Ensures that only the router can call the function
    modifier onlyRouter() {
        if (msg.sender != address(router)) revert OnlyRouter();
        _;
    }

    /// @notice Ensures that only LaPoste can call the function
    modifier onlyLaPoste() {
        if (msg.sender != laPoste) revert OnlyLaPoste();
        _;
    }

    /// @notice Constructs the Adapter contract
    /// @param _laPoste The address of the LaPoste contract
    /// @param _router The address of the CCIP router
    /// @param _baseGasLimit The base gas limit for cross-chain transactions
    constructor(address _laPoste, address _router, uint256 _baseGasLimit) {
        laPoste = _laPoste;
        router = IRouter(_router);
        BASE_GAS_LIMIT = _baseGasLimit;
    }

    /// @notice Sends a message to another chain
    /// @param executionGasLimit The gas limit for executing the message on the destination chain
    /// @param destinationChainId The ID of the destination chain
    /// @param message The message to be sent
    /// @return The address of the router and the message ID
    function sendMessage(address to, uint256 executionGasLimit, uint256 destinationChainId, bytes calldata message)
        external
        payable
        onlyLaPoste
        returns (bytes32)
    {
        if (destinationChainId == block.chainid) revert SameChain();

        uint64 chainSelector = getBridgeChainId(destinationChainId).toUint64();
        if (!router.isChainSupported(chainSelector)) revert InvalidChainId();

        uint256 totalGasLimit = executionGasLimit + BASE_GAS_LIMIT;

        Client.EVMExtraArgsV1 memory evmExtraArgs = Client.EVMExtraArgsV1({gasLimit: totalGasLimit});
        bytes memory extraArgs = Client._argsToBytes(evmExtraArgs);

        Client.EVM2AnyMessage memory ccipMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(to),
            data: message,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            feeToken: address(0),
            extraArgs: extraArgs
        });

        uint256 fee = router.getFee(chainSelector, ccipMessage);

        if (fee == 0) revert InvalidMessage();
        if (msg.value < fee) revert NotEnoughFee();

        return router.ccipSend{value: fee}(chainSelector, ccipMessage);
    }

    /// @notice Receives a message from another chain
    /// @param message The received message
    function ccipReceive(Client.Any2EVMMessage calldata message) external override onlyRouter {
        address source = abi.decode(message.sender, (address));
        if (source == address(0) || source != laPoste) revert InvalidSender();

        IAdapter(laPoste).receiveMessage({chainId: getChainId(message.sourceChainSelector), payload: message.data});
    }

    /// @notice Converts a bridge chain ID to a standard chain ID
    /// @param bridgeChainId The bridge chain ID
    /// @return The corresponding standard chain ID
    function getChainId(uint256 bridgeChainId) public pure returns (uint256) {
        if (bridgeChainId == CCIPSelectors.MAINNET) return Chains.MAINNET;
        else if (bridgeChainId == CCIPSelectors.AVALANCHE) return Chains.AVALANCHE;
        else if (bridgeChainId == CCIPSelectors.POLYGON) return Chains.POLYGON;
        else if (bridgeChainId == CCIPSelectors.ARBITRUM) return Chains.ARBITRUM;
        else if (bridgeChainId == CCIPSelectors.OPTIMISM) return Chains.OPTIMISM;
        else if (bridgeChainId == CCIPSelectors.BNB) return Chains.BNB;
        else if (bridgeChainId == CCIPSelectors.BASE) return Chains.BASE;
        else if (bridgeChainId == CCIPSelectors.ZKSYNC) return Chains.ZKSYNC;
        else if (bridgeChainId == CCIPSelectors.GNOSIS) return Chains.GNOSIS;
        else if (bridgeChainId == CCIPSelectors.LINEA) return Chains.LINEA;
        else if (bridgeChainId == CCIPSelectors.SCROLL) return Chains.SCROLL;
        else if (bridgeChainId == CCIPSelectors.CELO) return Chains.CELO;
        else if (bridgeChainId == CCIPSelectors.BLAST) return Chains.BLAST;

        return bridgeChainId;
    }

    /// @notice Converts a standard chain ID to a bridge chain ID
    /// @param chainId The standard chain ID
    /// @return The corresponding bridge chain ID
    function getBridgeChainId(uint256 chainId) public pure returns (uint256) {
        if (chainId == Chains.MAINNET) return CCIPSelectors.MAINNET;
        else if (chainId == Chains.AVALANCHE) return CCIPSelectors.AVALANCHE;
        else if (chainId == Chains.POLYGON) return CCIPSelectors.POLYGON;
        else if (chainId == Chains.ARBITRUM) return CCIPSelectors.ARBITRUM;
        else if (chainId == Chains.OPTIMISM) return CCIPSelectors.OPTIMISM;
        else if (chainId == Chains.BNB) return CCIPSelectors.BNB;
        else if (chainId == Chains.BASE) return CCIPSelectors.BASE;
        else if (chainId == Chains.ZKSYNC) return CCIPSelectors.ZKSYNC;
        else if (chainId == Chains.GNOSIS) return CCIPSelectors.GNOSIS;
        else if (chainId == Chains.LINEA) return CCIPSelectors.LINEA;
        else if (chainId == Chains.SCROLL) return CCIPSelectors.SCROLL;
        else if (chainId == Chains.CELO) return CCIPSelectors.CELO;
        else if (chainId == Chains.BLAST) return CCIPSelectors.BLAST;

        return chainId;
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
