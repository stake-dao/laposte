// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import "@forge-std/mocks/MockERC20.sol";

import "src/ccip/Adapter.sol";

import {LaPoste} from "src/LaPoste.sol";

import {Token} from "src/Token.sol";
import {TokenFactory} from "src/TokenFactory.sol";

contract Integration is Test {
    using SafeCast for uint256;

    LaPoste public laPoste;
    Adapter public adapter;
    TokenFactory public tokenFactory;

    address public constant CRV = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address public constant CCIP_ROUTER = address(0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D);

    function setUp() public {
        vm.createSelectFork("mainnet");

        tokenFactory = new TokenFactory(address(this), Chains.MAINNET);
        laPoste = new LaPoste(address(tokenFactory), address(this));

        tokenFactory.setMinter(address(laPoste));

        adapter = new Adapter(address(laPoste), CCIP_ROUTER, 200_000);
        laPoste.setAdapter(address(adapter));
    }

    function test_setup() public view {
        assertEq(laPoste.adapter(), address(adapter));
        assertEq(laPoste.tokenFactory(), address(tokenFactory));

        assertEq(address(adapter.router()), CCIP_ROUTER);
        assertEq(adapter.laPoste(), address(laPoste));
        assertEq(adapter.BASE_GAS_LIMIT(), 200_000);

        assertEq(tokenFactory.owner(), address(0));
        assertEq(tokenFactory.minter(), address(laPoste));
    }

    function test_sendMessage() public {
        address receiver = address(this);
        uint256 executionGasLimit = 100_000;
        uint256 destinationChainId = 1;
        bytes memory message = abi.encode(1);

        // 1. Same chain
        vm.expectRevert(Adapter.SameChain.selector);
        adapter.sendMessage(address(adapter), executionGasLimit, destinationChainId, message);

        // 3. Invalid chain
        vm.expectRevert(Adapter.InvalidChainId.selector);
        adapter.sendMessage(address(adapter), executionGasLimit, 1e18, message);

        /// Arbitrum
        destinationChainId = Chains.ARBITRUM;

        vm.expectRevert(Adapter.NotEnoughFee.selector);
        adapter.sendMessage(address(adapter), executionGasLimit, destinationChainId, message);

        uint256 fee = getFee(destinationChainId, receiver, executionGasLimit, message);

        vm.deal(address(this), fee);
        adapter.sendMessage{value: fee}(address(adapter), executionGasLimit, destinationChainId, message);

        IAdapter.Message memory laPosteMessage = IAdapter.Message({
            destinationChainId: destinationChainId,
            to: receiver,
            sender: address(laPoste),
            token: IAdapter.Token({tokenAddress: address(0), amount: 0}),
            tokenMetadata: IAdapter.TokenMetadata({name: "", symbol: "", decimals: 0}),
            payload: message,
            nonce: 0
        });

        vm.deal(address(this), fee);
        laPoste.sendMessage{value: fee}(laPosteMessage, executionGasLimit);
    }

    function test_sendMessageWithTokenOnMainnet() public {
        address receiver = address(this);
        uint256 executionGasLimit = 100_000;
        uint256 destinationChainId = Chains.ARBITRUM;
        bytes memory message = abi.encode(1);

        IAdapter.Message memory laPosteMessage = IAdapter.Message({
            destinationChainId: destinationChainId,
            to: receiver,
            sender: address(laPoste),
            token: IAdapter.Token({tokenAddress: CRV, amount: 1e18}),
            tokenMetadata: IAdapter.TokenMetadata({name: "Curve.fi CRV", symbol: "CRV", decimals: 18}),
            payload: message,
            nonce: 0
        });

        uint256 fee = getFee(destinationChainId, receiver, executionGasLimit, message);

        deal(address(CRV), address(this), 1e18);
        deal(address(this), fee);

        IERC20(CRV).approve(address(tokenFactory), 1e18);
        laPoste.sendMessage{value: fee}(laPosteMessage, executionGasLimit);

        assertEq(IERC20(CRV).balanceOf(address(this)), 0);
        assertEq(IERC20(CRV).balanceOf(address(laPoste)), 0);
        assertEq(IERC20(CRV).balanceOf(address(adapter)), 0);
        assertEq(IERC20(CRV).balanceOf(address(tokenFactory)), 1e18);
    }

    function test_receiveMessageWithTokenOnSidechain() public {
        address receiver = address(this);
        uint256 executionGasLimit = 100_000;
        uint256 destinationChainId = Chains.ARBITRUM;
        bytes memory message = abi.encode(1);

        IAdapter.Message memory laPosteMessage = IAdapter.Message({
            destinationChainId: destinationChainId,
            to: receiver,
            sender: address(laPoste),
            token: IAdapter.Token({tokenAddress: CRV, amount: 1e18}),
            tokenMetadata: IAdapter.TokenMetadata({name: "Curve.fi CRV", symbol: "CRV", decimals: 18}),
            payload: message,
            nonce: 0
        });

        uint256 fee = getFee(destinationChainId, receiver, executionGasLimit, message);

        vm.chainId(Chains.OPTIMISM);

        deal(address(CRV), address(this), 1e18);
        deal(address(this), fee);

        IERC20(CRV).approve(address(tokenFactory), 1e18);
        vm.expectRevert(TokenFactory.WrappedTokenDoesNotExist.selector);
        laPoste.sendMessage{value: fee}(laPosteMessage, executionGasLimit);
    }

    function test_receiveMessageWithToken() public {
        address receiver = address(this);
        uint256 destinationChainId = Chains.ARBITRUM;

        /// As if we received a message from Arbitrum.
        deal(address(CRV), address(laPoste), 1e18);

        vm.prank(address(laPoste));
        IERC20(CRV).approve(address(tokenFactory), 1e18);

        vm.prank(address(laPoste));
        tokenFactory.burn(CRV, address(laPoste), 1e18);

        IAdapter.Message memory laPosteMessage = IAdapter.Message({
            destinationChainId: Chains.MAINNET,
            to: receiver,
            sender: address(laPoste),
            token: IAdapter.Token({tokenAddress: CRV, amount: 1e18}),
            tokenMetadata: IAdapter.TokenMetadata({name: "Curve.fi CRV", symbol: "CRV", decimals: 18}),
            payload: "",
            nonce: 0
        });

        assertEq(laPoste.receivedNonces(destinationChainId), 0);

        vm.expectRevert(LaPoste.OnlyAdapter.selector);
        laPoste.receiveMessage(destinationChainId, abi.encode(laPosteMessage));

        vm.prank(address(adapter));
        vm.expectRevert(LaPoste.MessageAlreadyProcessed.selector);
        laPoste.receiveMessage(destinationChainId, abi.encode(laPosteMessage));

        laPosteMessage.nonce = 1;

        vm.prank(address(adapter));
        laPoste.receiveMessage(destinationChainId, abi.encode(laPosteMessage));

        assertEq(laPoste.receivedNonces(destinationChainId), 1);

        vm.prank(address(adapter));
        vm.expectRevert(LaPoste.MessageAlreadyProcessed.selector);
        laPoste.receiveMessage(destinationChainId, abi.encode(laPosteMessage));

        assertEq(IERC20(CRV).balanceOf(address(this)), 1e18);
    }

    function test_receiveMessageFromSidechain() public {
        address receiver = address(this);
        uint256 destinationChainId = Chains.MAINNET;

        IAdapter.Message memory laPosteMessage = IAdapter.Message({
            destinationChainId: destinationChainId,
            to: receiver,
            sender: address(laPoste),
            token: IAdapter.Token({tokenAddress: CRV, amount: 1e18}),
            tokenMetadata: IAdapter.TokenMetadata({name: "Curve.fi CRV", symbol: "CRV", decimals: 18}),
            payload: "",
            nonce: 0
        });

        assertEq(laPoste.receivedNonces(destinationChainId), 0);

        vm.expectRevert(LaPoste.OnlyAdapter.selector);
        laPoste.receiveMessage(destinationChainId, abi.encode(laPosteMessage));

        vm.prank(address(adapter));
        vm.expectRevert(LaPoste.MessageAlreadyProcessed.selector);
        laPoste.receiveMessage(destinationChainId, abi.encode(laPosteMessage));

        laPosteMessage.nonce = 1;

        deal(CRV, address(tokenFactory), 1e18);

        vm.prank(address(adapter));
        laPoste.receiveMessage(destinationChainId, abi.encode(laPosteMessage));

        assertEq(laPoste.receivedNonces(destinationChainId), 1);

        vm.prank(address(adapter));
        vm.expectRevert(LaPoste.MessageAlreadyProcessed.selector);
        laPoste.receiveMessage(destinationChainId, abi.encode(laPosteMessage));

        assertEq(IERC20(CRV).balanceOf(receiver), 1e18);
    }

    function test_setAdapter() public {
        address newAdapter = address(0x123);

        vm.prank(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        laPoste.setAdapter(newAdapter);

        laPoste.setAdapter(newAdapter);
        assertEq(laPoste.adapter(), newAdapter);
    }

    function test_token() public {
        string memory name = "Test Token";
        string memory symbol = "TST";
        uint8 decimals = 18;

        Token token = new Token(name, symbol, decimals);

        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.decimals(), decimals);

        address receiver = address(0x123);
        uint256 amount = 1e18;

        token.mint(receiver, amount);
        assertEq(token.balanceOf(receiver), amount);

        token.burn(receiver, amount / 2);
        assertEq(token.balanceOf(receiver), amount / 2);

        assertEq(token.version(), "LaPoste Token v1");
    }

    function getFee(uint256 destinationChainId, address receiver, uint256 executionGasLimit, bytes memory message)
        public
        view
        returns (uint256)
    {
        Client.EVMExtraArgsV1 memory evmExtraArgs =
            Client.EVMExtraArgsV1({gasLimit: executionGasLimit + adapter.BASE_GAS_LIMIT()});
        bytes memory extraArgs = Client._argsToBytes(evmExtraArgs);

        Client.EVM2AnyMessage memory ccipMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: message,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            feeToken: address(0),
            extraArgs: extraArgs
        });

        uint64 chainSelector = adapter.getBridgeChainId(destinationChainId).toUint64();
        uint256 fee = IRouter(CCIP_ROUTER).getFee(chainSelector, ccipMessage);

        /// Add an extra 20% buffer.
        fee += (fee * 20) / 100;

        return fee;
    }
}
