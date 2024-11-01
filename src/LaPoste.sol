// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/interfaces/ILaPoste.sol";
import "src/interfaces/IAdapter.sol";
import "src/interfaces/ITokenFactory.sol";
import "src/interfaces/IMessageReceiver.sol";

import "@openzeppelin/contracts/utils/Address.sol";
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
    mapping(uint256 => mapping(uint256 => bool)) public receivedNonces;

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
        uint256 indexed chainId, uint256 indexed nonce, address indexed sender, address to, ILaPoste.Message message
    );

    event MessageReceived(
        uint256 indexed chainId,
        uint256 indexed nonce,
        address indexed sender,
        address to,
        ILaPoste.Message message,
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
    /// @param messageParams The message parameters
    /// @dev This function is payable to cover cross-chain fees
    function sendMessage(ILaPoste.MessageParams memory messageParams, uint256 additionalGasLimit, address refundAddress)
        external
        payable
    {
        if (adapter == address(0)) revert NoAdapterSet();
        if (messageParams.destinationChainId == block.chainid) revert CannotSendToSelf();

        /// 0. Initialize the message.
        ILaPoste.Message memory message;

        /// 1. Set the message fields.
        message.destinationChainId = messageParams.destinationChainId;
        message.to = messageParams.to;
        message.sender = msg.sender;
        message.payload = messageParams.payload;

        /// 2. Set the nonce in the message
        message.nonce = sentNonces[message.destinationChainId] + 1;

        /// 3. Check if there's a token attached and mint it to the receiver.
        if (messageParams.token.tokenAddress != address(0)) {
            message.token = messageParams.token;

            ITokenFactory(tokenFactory).burn(messageParams.token.tokenAddress, msg.sender, messageParams.token.amount);

            (message.tokenMetadata.name, message.tokenMetadata.symbol, message.tokenMetadata.decimals) =
                ITokenFactory(tokenFactory).getTokenMetadata(messageParams.token.tokenAddress);
        }

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

        /// 4. Set the refund address if not provided.
        if (refundAddress == address(0)) {
            refundAddress = msg.sender;
        }

        // 4. Increment the sent nonce for the specific chain after successful send
        sentNonces[message.destinationChainId] = message.nonce;

        /// 5. Refund the sender.
        Address.sendValue(payable(refundAddress), address(this).balance);

        emit MessageSent(message.destinationChainId, message.nonce, msg.sender, message.to, message);
    }

    /// @notice Receives a message from another chain
    /// @param chainId The ID of the source chain
    /// @param payload The encoded message payload
    function receiveMessage(uint256 chainId, bytes calldata payload) external onlyAdapter {
        ILaPoste.Message memory message = abi.decode(payload, (ILaPoste.Message));

        // Check if the message has already been processed
        if (receivedNonces[chainId][message.nonce]) revert MessageAlreadyProcessed();

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
        bool success = true;
        if (message.payload.length > 0) {
            try IMessageReceiver(message.to).receiveMessage(chainId, message.sender, message.payload) {}
            catch {
                success = false;
            }
        }

        // 3. Update the received nonce for the specific chain
        receivedNonces[chainId][message.nonce] = true;

        emit MessageReceived(chainId, message.nonce, message.sender, message.to, message, success);
    }

    /// @notice Sets the adapter address
    /// @param _adapter The address of the new adapter
    /// @dev It should be updated on all chains.
    function setAdapter(address _adapter) external onlyOwner {
        adapter = _adapter;
    }
}
