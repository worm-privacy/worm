// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BETH} from "../src/BETH.sol";
import {WORM} from "../src/WORM.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";
import {Staking} from "../src/Staking.sol";

contract AlwaysVerify is IVerifier {
    function verifyProof(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[1] calldata _pubSignals
    ) external returns (bool) {
        return true;
    }
}

interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

contract FakePool is IUniswapV3Pool {
    IERC20 beth;

    constructor(IERC20 _beth) {
        beth = _beth;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        beth.transferFrom(msg.sender, address(this), uint256(amountSpecified));
        (bool success,) = recipient.call{value: uint256(amountSpecified)}("");
        require(success, "TF");
    }
}

contract BETHTest is Test {
    BETH public beth;
    WORM public worm;
    Staking public rewardPool;
    address alice = address(0xa11ce);
    address bob = address(0xb0b);
    address charlie = address(0xc4a);
    IUniswapV3Pool fakePool;

    function setUp() public {
        beth = new BETH(new AlwaysVerify(), new AlwaysVerify(), address(0), 0, address(this));
        worm = new WORM(beth, alice, 10 ether, 0);
        rewardPool = new Staking(worm, beth, 7 days, 0);
        beth.initRewardPool(rewardPool);
        fakePool = new FakePool(beth);
        vm.deal(address(fakePool), 100 ether);
    }

    function test_nonInitialized() public {
        BETH beth2 = new BETH(new AlwaysVerify(), new AlwaysVerify(), address(0), 0, address(this));
        IUniswapV3Pool fakePool2 = new FakePool(beth2);
        vm.deal(address(fakePool2), 100 ether);
        bytes memory receiverHook = abi.encode(
            address(fakePool2),
            0.01 ether,
            abi.encodeWithSelector(IUniswapV3Pool.swap.selector, charlie, false, 0.01 ether, 0, new bytes(0))
        );
        beth2.mintCoin(
            BETH.MintParams({
                pA: [uint256(0), uint256(0)],
                pB: [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
                pC: [uint256(0), uint256(0)],
                blockNumber: block.number - 1,
                nullifier: 123,
                remainingCoin: 234,
                broadcasterFee: 0.1 ether,
                revealedAmount: 1 ether,
                revealedAmountReceiver: alice,
                proverFee: 0.2 ether,
                prover: bob,
                receiverPostMintHook: receiverHook,
                broadcasterFeePostMintHook: new bytes(0),
                proverFeePostMintHook: new bytes(0)
            })
        );
        assertEq(beth2.balanceOf(alice), 1 ether - 0.1 ether - 0.2 ether - 0.01 ether);
        assertEq(beth2.balanceOf(address(fakePool2)), 0.01 ether);
        assertEq(address(fakePool2).balance, 99.99 ether);
        assertEq(charlie.balance, 0.01 ether);
        assertEq(beth2.totalSupply(), 1 ether);
        assertEq(beth2.balanceOf(address(this)), 0.1 ether);
        assertEq(beth2.balanceOf(bob), 0.2 ether);
    }

    function test_mint() public {
        bytes memory receiverHook = abi.encode(
            address(fakePool),
            0.01 ether,
            abi.encodeWithSelector(IUniswapV3Pool.swap.selector, charlie, false, 0.01 ether, 0, new bytes(0))
        );

        assertEq(worm.balanceOf(alice), 10 ether);
        beth.mintCoin(
            BETH.MintParams({
                pA: [uint256(0), uint256(0)],
                pB: [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
                pC: [uint256(0), uint256(0)],
                blockNumber: block.number - 1,
                nullifier: 123,
                remainingCoin: 234,
                broadcasterFee: 0.1 ether,
                revealedAmount: 1 ether,
                revealedAmountReceiver: alice,
                proverFee: 0.2 ether,
                prover: bob,
                receiverPostMintHook: receiverHook,
                broadcasterFeePostMintHook: new bytes(0),
                proverFeePostMintHook: new bytes(0)
            })
        );
        assertEq(beth.balanceOf(alice), 1 ether - 0.1 ether - 0.2 ether - 0.01 ether - (1 ether / 200));
        assertEq(beth.balanceOf(address(fakePool)), 0.01 ether);
        assertEq(address(fakePool).balance, 99.99 ether);
        assertEq(charlie.balance, 0.01 ether);
        assertEq(beth.totalSupply(), 1 ether);
        assertEq(beth.balanceOf(address(this)), 0.1 ether);
        assertEq(beth.balanceOf(bob), 0.2 ether);
        assertEq(beth.balanceOf(address(rewardPool)), (1 ether / 200));
    }

    function test_spend() public {
        assertEq(worm.balanceOf(alice), 10 ether);
        beth.mintCoin(
            BETH.MintParams({
                pA: [uint256(0), uint256(0)],
                pB: [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
                pC: [uint256(0), uint256(0)],
                blockNumber: block.number - 1,
                nullifier: 123,
                remainingCoin: 234,
                broadcasterFee: 0.1 ether,
                revealedAmount: 1 ether,
                revealedAmountReceiver: alice,
                proverFee: 0.2 ether,
                prover: bob,
                receiverPostMintHook: new bytes(0),
                broadcasterFeePostMintHook: new bytes(0),
                proverFeePostMintHook: new bytes(0)
            })
        );
        assertEq(beth.balanceOf(alice), 1 ether - 0.1 ether - 0.2 ether - (1 ether / 200));
        assertEq(beth.totalSupply(), 1 ether);
        assertEq(beth.balanceOf(address(this)), 0.1 ether);
        assertEq(beth.balanceOf(bob), 0.2 ether);
        assertEq(beth.balanceOf(address(rewardPool)), (1 ether / 200));

        beth.spendCoin(
            BETH.SpendParams({
                pA: [uint256(0), uint256(0)],
                pB: [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
                pC: [uint256(0), uint256(0)],
                coin: 234,
                revealedAmount: 1 ether,
                remainingCoin: 456
            })
        );

        assertEq(
            beth.balanceOf(alice), (1 ether - 0.1 ether - 0.2 ether - (1 ether / 200)) + (1 ether - (1 ether / 200))
        );
        assertEq(beth.totalSupply(), 1 ether + 1 ether);
        assertEq(beth.balanceOf(address(this)), 0.1 ether);
        assertEq(beth.balanceOf(bob), 0.2 ether);
        assertEq(beth.balanceOf(address(rewardPool)), 2 * (1 ether / 200));

        beth.spendCoin(
            BETH.SpendParams({
                pA: [uint256(0), uint256(0)],
                pB: [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
                pC: [uint256(0), uint256(0)],
                coin: 456,
                revealedAmount: 1 ether,
                remainingCoin: 567
            })
        );

        assertEq(
            beth.balanceOf(alice),
            (1 ether - 0.1 ether - 0.2 ether - (1 ether / 200))
                + (1 ether - (1 ether / 200) + (1 ether - (1 ether / 200)))
        );
        assertEq(beth.totalSupply(), 1 ether + 1 ether + 1 ether);
        assertEq(beth.balanceOf(address(this)), 0.1 ether);
        assertEq(beth.balanceOf(bob), 0.2 ether);
        assertEq(beth.balanceOf(address(rewardPool)), 3 * (1 ether / 200));
    }

    function test_proof_of_burn_public_commitment() public pure {
        assertEq(
            uint256(
                keccak256(
                    abi.encodePacked(
                        uint256(59143423853376781417125983618613228280659999960210986093114662880508950626056),
                        uint256(6440986494580578507067062322918826161607249544152625345271923997131881196551),
                        uint256(17037121386624115832741779956926083357970021470596072423532449206176480530268),
                        uint256(123),
                        uint256(234),
                        uint256(827641930419614124039720421795580660909102123457)
                    )
                ) >> 8
            ),
            uint256(357580174033218738890059651196032050606164050021517478600256431899986052418)
        );
    }
}
