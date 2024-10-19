// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import "@forge-std/mocks/MockERC20.sol";

import "src/ccip/Adapter.sol";

contract AdapterTest is Test {
    using SafeCast for uint256;

    Adapter public adapter;

    address public laPoste = address(0x1);
    address public router = address(this);

    function setUp() public {
        adapter = new Adapter({_laPoste: laPoste, _router: router, _baseGasLimit: 200_000});
    }

    function test_setup() public view {
        assertEq(adapter.laPoste(), address(0x1));

        address _router = address(adapter.router());
        assertEq(_router, router);

        assertEq(adapter.BASE_GAS_LIMIT(), 200_000);
    }

    function test_sendMessage() public {
        /// Parameters
        address receiver = address(0x2);
        uint256 executionGasLimit = 100_000;
        uint256 destinationChainId = 1;
        bytes memory message = abi.encode("Hello World");

        /// Set the chain ID.
        vm.chainId(1);

        vm.expectRevert(Adapter.OnlyLaPoste.selector);
        adapter.sendMessage(receiver, executionGasLimit, destinationChainId, message);

        vm.prank(laPoste);
        vm.expectRevert(Adapter.SameChain.selector);
        adapter.sendMessage(receiver, executionGasLimit, destinationChainId, message);

        /// Change the chain ID to 2.
        vm.chainId(2);

        uint64 chainSelector = adapter.getBridgeChainId(destinationChainId).toUint64();

        /// Mock the isChainSupported function to return false.
        vm.mockCall(
            router,
            abi.encodeWithSelector(IRouter.isChainSupported.selector, chainSelector),
            abi.encode(bytes32(0))
        );

        vm.prank(laPoste);
        vm.expectRevert(Adapter.InvalidChainId.selector);
        adapter.sendMessage(receiver, executionGasLimit, destinationChainId, message);

        vm.clearMockedCalls();

        Client.EVMExtraArgsV1 memory evmExtraArgs = Client.EVMExtraArgsV1({gasLimit: executionGasLimit + adapter.BASE_GAS_LIMIT()});
        bytes memory extraArgs = Client._argsToBytes(evmExtraArgs);

        Client.EVM2AnyMessage memory ccipMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: message,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            feeToken: address(0),
            extraArgs: extraArgs
        });

        /// Mock the getFee function to return 0.
        vm.mockCall(
            router,
            abi.encodeWithSelector(IRouter.getFee.selector, chainSelector, ccipMessage),
            abi.encode(0)
        );

        vm.prank(laPoste);
        vm.expectRevert(Adapter.InvalidMessage.selector);
        adapter.sendMessage(receiver, executionGasLimit, destinationChainId, message);

        vm.clearMockedCalls();

        vm.prank(laPoste);
        vm.expectRevert(Adapter.NotEnoughFee.selector);
        adapter.sendMessage(receiver, executionGasLimit, destinationChainId, message);

        hoax(laPoste);
        bytes32 messageId = adapter.sendMessage{value: 100}(receiver, executionGasLimit, destinationChainId, message);
        assertEq(messageId, bytes32("Success"));
    }

    /// Mocked functions
    function isChainSupported(uint64) external pure returns (bool) {
        return true;
    }

    function getFee(uint64, Client.EVM2AnyMessage memory) external pure returns (uint256) {
        return 100;
    }

    function ccipSend(uint64, Client.EVM2AnyMessage memory) external payable returns (bytes32) {
        return bytes32("Success");
    }
}
