// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// ##########################################################################################
/// ##########################################################################################
/// ##########################################################################################
/// ##########################################################################################
/// ##########################################################################################
/// ##########################################################################################
/// ##########################################################################################
/// #############################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓############################
/// ###############################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓##########################
/// ###################################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓###########################
/// ########################################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓############################
/// ##########################################################################################
/// ########################################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓###############
/// #####################################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓###################
/// ##################################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓###########################
/// ##############################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓##################################
/// ###########################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓#########################################
/// ########################▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓########▓▓▓▓▓####################################
/// #####################▓▓▓▓▓▓▓▓▓▓▓▓▓#######▓▓▓▓▓▓▓▓▓▓▓▓#####################################
/// ##################▓▓▓▓▓▓▓▓########▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓######################################
/// ###############▓▓▓▓#########▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓#########################################
/// ##########################################################################################
/// ##########################################################################################
/// ##########################################################################################
/// ################▓▓#######▓▓▓######▓▓▓▓▓▓▓##▓▓▓▓▓▓▓##▓▓▓#▓▓#▓▓▓▓▓▓▓#▓▓▓▓▓▓#################
/// ################▓▓######▓▓#▓▓#####▓▓##▓▓▓#▓▓#####▓▓#▓▓▓▓▓▓####▓▓###▓▓▓▓▓▓#################
/// ################▓▓#####▓▓▓▓▓▓▓####▓▓▓▓####▓▓▓###▓▓▓#▓###▓▓▓###▓▓###▓▓#####################
/// #################▓▓▓▓##▓######▓####▓########▓▓▓▓#####▓▓▓▓#####▓#####▓▓▓▓▓▓################
/// ##########################################################################################
/// ##########################################################################################
/// ##########################################################################################
/// ##########################################################################################
/// ##########################################################################################
/// ##########################################################################################

import "src/interfaces/IAdapter.sol";
import "src/interfaces/ITokenFactory.sol";
import "src/interfaces/IMessageReceiver.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title LaPoste
/// @notice A contract for cross-chain message passing and token transfers
/// @author StakeDAO - @warrenception
/// @dev This contract uses a single adapter for governance-controlled bridge interactions
contract LaPoste is Ownable2Step {
    using SafeERC20 for IERC20;

    /// @notice The address of the token factory
    address public immutable tokenFactory;

    /// @notice The address of the adapter
    address public adapter;

    /// @notice Nonce for sent messages, per chain
    mapping(uint256 => uint256) public sentNonces;

    /// @notice Nonce for received messages, per chain
    mapping(uint256 => uint256) public receivedNonces;

    /// @notice Thrown when the sender is not the adapter.
    error OnlyAdapter();
    /// @notice Thrown when no adapter is set.
    error NoAdapterSet();
    /// @notice Thrown when a message execution fails.
    error ExecutionFailed();
    /// @notice Thrown when a message is expired.
    error ExpiredMessage();
    /// @notice Thrown when a message has already been processed.
    error MessageAlreadyProcessed();
    /// @notice Thrown when a message is sent to the same chain.
    error CannotSendToSelf();

    event MessageSent(
        uint256 indexed chainId, uint256 indexed nonce, address indexed sender, address to, IAdapter.Message message
    );

    event MessageReceived(
        uint256 indexed chainId,
        uint256 indexed nonce,
        address indexed sender,
        address to,
        IAdapter.Message message,
        bool success
    );

    /// @notice Ensures that only the adapter can call the function.
    modifier onlyAdapter() {
        if (msg.sender != adapter) revert OnlyAdapter();
        _;
    }

    /// @notice Constructs the LaPoste contract.
    /// @param _tokenFactory The address of the token factory.
    constructor(address _tokenFactory, address _owner) {
        tokenFactory = _tokenFactory;
        _transferOwnership(_owner);
    }

    /// @notice Sends a message across chains
    /// @param message The message to send
    /// @dev This function is payable to cover cross-chain fees
    function sendMessage(IAdapter.Message memory message, uint256 additionalGasLimit) external payable {
        if (adapter == address(0)) revert NoAdapterSet();
        if (message.destinationChainId == block.chainid) revert CannotSendToSelf();

        /// 1. Check if there's a token attached and mint it to the receiver.
        if (message.token.tokenAddress != address(0)) {
            ITokenFactory(tokenFactory).burn(message.token.tokenAddress, message.to, message.token.amount);

            (message.tokenMetadata.name, message.tokenMetadata.symbol, message.tokenMetadata.decimals) =
                ITokenFactory(tokenFactory).getTokenMetadata(message.token.tokenAddress);
        }

        /// 1. Set the nonce in the message
        message.nonce = sentNonces[message.destinationChainId] + 1;

        /// 2. Set the sender to the message sender
        message.sender = msg.sender;

        (bool success,) = adapter.delegatecall(
            abi.encodeWithSelector(
                IAdapter.sendMessage.selector,
                adapter,
                additionalGasLimit,
                message.destinationChainId,
                abi.encode(message)
            )
        );
        if (!success) revert ExecutionFailed();

        // Increment the sent nonce for the specific chain after successful send
        sentNonces[message.destinationChainId] = message.nonce;

        emit MessageSent(message.destinationChainId, message.nonce, msg.sender, message.to, message);
    }

    /// @notice Receives a message from another chain
    /// @param chainId The ID of the source chain
    /// @param payload The encoded message payload
    function receiveMessage(uint256 chainId, bytes calldata payload) external onlyAdapter {
        IAdapter.Message memory message = abi.decode(payload, (IAdapter.Message));

        // Check if the message has already been processed
        if (message.nonce <= receivedNonces[chainId]) revert MessageAlreadyProcessed();

        /// 1. Check if there's a token attached and release or mint it to the receiver.
        if (message.token.tokenAddress != address(0) && message.token.amount > 0) {
            ITokenFactory(tokenFactory).mint(
                message.token.tokenAddress,
                message.to,
                message.token.amount,
                message.tokenMetadata.name,
                message.tokenMetadata.symbol,
                message.tokenMetadata.decimals
            );
        }

        /// 2. Execute the message.
        bool success;
        if (message.payload.length > 0 && message.to != tokenFactory) {
            (success,) = message.to.call(message.payload);
        }

        // Update the received nonce for the specific chain
        receivedNonces[chainId] = message.nonce;

        emit MessageReceived(chainId, message.nonce, message.sender, message.to, message, success);
    }

    /// @notice Sets the adapter address
    /// @param _adapter The address of the new adapter
    /// @dev It should be updated on all chains.
    function setAdapter(address _adapter) external onlyOwner {
        adapter = _adapter;
    }
}
