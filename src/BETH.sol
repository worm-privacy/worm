// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IRewardPool} from "./Staking.sol";
import {IVerifier} from "./IVerifier.sol";

contract BETH is ERC20, ReentrancyGuard {
    event HookFailure(bytes returnData);

    uint256 public constant MINT_CAP = 10 ether;
    uint256 public constant POOL_SHARE_INV = 200; // 1 / 200 = 0.5%

    address initializer; // The address which has the permission to initialize the rewardPool
    IRewardPool public rewardPool;

    IVerifier public proofOfBurnVerifier;
    IVerifier public spendVerifier;
    mapping(uint256 => bool) public nullifiers;
    mapping(uint256 => uint256) public coinSource; // Map each coin to its root coin
    mapping(uint256 => uint256) public coinRevealed; // Total revealed amount of a root coin

    constructor(
        IVerifier _proofOfBurnVerifier,
        IVerifier _spendVerifier,
        address _premineAddress,
        uint256 _premineAmount
    ) ERC20("Burned ETH", "BETH") {
        proofOfBurnVerifier = _proofOfBurnVerifier;
        spendVerifier = _spendVerifier;
        initializer = msg.sender;
        if (_premineAddress != address(0)) {
            _mint(_premineAddress, _premineAmount);
        }
    }

    /**
     * @notice Initializes the reward pool reference for this contract
     * @dev Can only be called once by the designated initializer.
     *      Prevents accidental or malicious re-initialization by enforcing
     *      that the stored reward pool address is zero.
     * @param _rewardPool The reward pool contract that will receive minted rewards
     */
    function initRewardPool(IRewardPool _rewardPool) external {
        require(msg.sender == initializer, "Only the initializer can initialize!");
        require(address(rewardPool) == address(0), "Reward pool already set!");
        rewardPool = _rewardPool;
    }

    /**
     * @dev Reverts if the reward pool address is still zero.
     */
    modifier isInitialized() {
        require(address(rewardPool) != address(0), "Reward pool not initialized!");
        _;
    }

    /**
     * @notice Mints tokens directly to this contract and deposits them into the reward pool
     * @dev Temporarily approves the reward pool to pull freshly minted tokens.
     *      Approval is reset to zero after the deposit to prevent lingering allowances.
     * @param _amount The number of tokens to mint and transfer to the reward pool
     */
    function mintForRewardPool(uint256 _amount) internal {
        _mint(address(this), _amount);
        _approve(address(this), address(rewardPool), _amount);
        rewardPool.depositReward(_amount);
        _approve(address(this), address(rewardPool), 0);
    }

    /**
     * @notice Handles optional post-mint hooks for BETH recipients
     * @dev Executes arbitrary calldata against a target contract with temporary token approval.
     *      Failure does not revert the main mint; only emits an event.
     * @param _hookData ABI-encoded (target address, allowance, calldata)
     */
    function handleHook(bytes memory _hookData) internal {
        // Hooks are optional
        if (_hookData.length != 0) {
            // Decode the hook parameters
            (address hookAddress, uint256 hookAllowance, bytes memory hookCalldata) =
                abi.decode(_hookData, (address, uint256, bytes));

            // Approve the hook to spend BETH
            this.approve(hookAddress, hookAllowance);

            // Execute the hook
            (bool success, bytes memory returnData) = hookAddress.call{value: 0}(hookCalldata);

            // Reset approval to zero for safety
            this.approve(hookAddress, 0);

            // No need to force `success` to be true. Failure should not prevent the burner from receiving their BETH.
            if (!success) {
                emit HookFailure(returnData);
            }
        }
    }

    /**
     * @notice Mints BETH to this contract, optionally executes a post-mint hook,
     *         then transfers the entire contract balance of freshly minted tokens
     *         to the final destination.
     * @param _destination  Final address receiving the leftover minted tokens.
     * @param _amount       Amount of tokens to mint before executing the hook.
     * @param _hookData     Encoded hook call data; empty means "no hook".
     */
    function mintAndTransfer(address _destination, uint256 _amount, bytes memory _hookData) internal {
        if (_amount > 0) {
            _mint(address(this), _amount);
            handleHook(_hookData);
            require(this.transfer(_destination, balanceOf(address(this))), "TF");
        }
    }

    /*
     * pA zkSNARK proof element A.
     * pB zkSNARK proof element B.
     * pC zkSNARK proof element C.
     * blockNumber The block number whose state root is used in the proof.
     * nullifier The nullifier derived from Poseidon2(POSEIDON_NULLIFIER_PREFIX, burnKey).
     * remainingCoin The encrypted leftover balance commitment.
     * broadcasterFee Fee paid to the relayer who submits the proof.
     * revealedAmount Amount directly revealed (minted to receiver).
     * revealedAmountReceiver Receiver of the directly revealed BETH.
     * proverFee Fee paid to the prover who generated the zk proof.
     * prover The address of the prover.
     * receiverPostMintHook The receiver may sell his BETH for ETH through a hook.
     * broadcasterFeePostMintHook The broadcaster may sell his BETH for ETH through a hook.
     */
    struct MintParams {
        // Proof elements
        uint256[2] pA;
        uint256[2][2] pB;
        uint256[2] pC;

        uint256 blockNumber;
        uint256 nullifier;
        uint256 remainingCoin;

        // Broadcaster's share
        uint256 broadcasterFee;
        bytes broadcasterFeePostMintHook;

        // Prover's share
        uint256 proverFee;
        address prover;
        bytes proverFeePostMintHook;

        // Burner's share (revealedAmountAfterFee - broadcasterFee - proverFee)
        uint256 revealedAmount;
        address revealedAmountReceiver;
        bytes receiverPostMintHook;
    }

    /**
     * @notice Mints new BETH tokens by proving ETH was burned to a valid burn address.
     * @dev This function verifies a zkSNARK proof generated by the ProofOfBurn circuit.
     * @param _mintParams All parameters within a struct
     */
    function mintCoin(MintParams calldata _mintParams) public nonReentrant isInitialized {
        // Information bound to the burn (shifted right by 8 to fit within field elements).
        // The burn address is computed as: Poseidon4(POSEIDON_BURN_PREFIX, burnKey, revealAmount, burnExtraCommitment)[:20].
        // Once ETH is sent to the burn address, the data in burnExtraCommitment cannot be changed.
        // This ensures that the broadcaster and prover cannot alter the BETH receiver
        // and cannot claim more BETH than the amount the burner has authorized.
        uint256 burnExtraCommitment =
            uint256(
                    keccak256(
                        abi.encodePacked(
                            _mintParams.broadcasterFee,
                            _mintParams.proverFee,
                            _mintParams.revealedAmountReceiver,
                            _mintParams.receiverPostMintHook
                        )
                    )
                ) >> 8;

        uint256 poolFee = _mintParams.revealedAmount / POOL_SHARE_INV; // 0.5%
        uint256 revealedAmountAfterFee = _mintParams.revealedAmount - poolFee;

        // Information bound to the proof (shifted right by 8 to fit within field elements).
        // The proof generation may be delegated to another party.
        // They can attach their address to the proof so that no one can steal the proverFee
        // by submitting the proof on their behalf.
        uint256 proofExtraCommitment =
            uint256(keccak256(abi.encodePacked(_mintParams.prover, _mintParams.proverFeePostMintHook))) >> 8;

        // Disallow minting more than a MINT_CAP through a single burn.
        require(_mintParams.revealedAmount <= MINT_CAP, "Mint is capped!");

        // Prover-fee and broadcaster-fee are paid from the revealed-amount!
        require(_mintParams.proverFee + _mintParams.broadcasterFee <= revealedAmountAfterFee, "More fee than revealed!");

        // Disallow minting a single burn-address twice.
        require(!nullifiers[_mintParams.nullifier], "Nullifier already consumed!");
        require(coinSource[_mintParams.remainingCoin] == 0, "Coin already minted!");

        bytes32 blockHash = blockhash(_mintParams.blockNumber);
        require(blockHash != bytes32(0), "Block root unavailable!");

        // Circuit public inputs are passed through a compact keccak hash for gas optimization.
        uint256 commitment =
            uint256(
                    keccak256(
                        abi.encodePacked(
                            blockHash,
                            _mintParams.nullifier,
                            _mintParams.remainingCoin,
                            _mintParams.revealedAmount,
                            burnExtraCommitment,
                            proofExtraCommitment
                        )
                    )
                ) >> 8;
        require(
            proofOfBurnVerifier.verifyProof(_mintParams.pA, _mintParams.pB, _mintParams.pC, [commitment]),
            "Invalid proof!"
        );

        nullifiers[_mintParams.nullifier] = true;
        coinSource[_mintParams.remainingCoin] = _mintParams.remainingCoin; // The source-coin of a fresh coin is itself
        coinRevealed[_mintParams.remainingCoin] = _mintParams.revealedAmount;

        // STATE CHANGES
        mintAndTransfer(_mintParams.prover, _mintParams.proverFee, _mintParams.proverFeePostMintHook);
        mintAndTransfer(msg.sender, _mintParams.broadcasterFee, _mintParams.broadcasterFeePostMintHook);
        mintAndTransfer(
            _mintParams.revealedAmountReceiver,
            revealedAmountAfterFee - _mintParams.broadcasterFee - _mintParams.proverFee,
            _mintParams.receiverPostMintHook
        );
        mintForRewardPool(poolFee);
    }

    /*
     * pA zkSNARK proof element A.
     * pB zkSNARK proof element B.
     * pC zkSNARK proof element C.
     * coin The encrypted coin being spent.
     * revealedAmount The amount being revealed/minted to the receiver.
     * remainingCoin The new encrypted coin for the remaining balance.
     * broadcasterFee Fee paid to the transaction sender.
     * receiver The address receiving the revealed amount.
     */
    struct SpendParams {
        uint256[2] pA;
        uint256[2][2] pB;
        uint256[2] pC;
        uint256 coin;
        uint256 revealedAmount;
        uint256 remainingCoin;
        uint256 broadcasterFee;
        address receiver;
    }

    /**
     * @notice Reveals part of an existing BETH "coin" using a zero-knowledge proof.
     * @param _spendParams All parameters within a struct
     */
    function spendCoin(SpendParams calldata _spendParams) public isInitialized nonReentrant {
        uint256 poolFee = _spendParams.revealedAmount / POOL_SHARE_INV; // 0.5%
        uint256 revealedAmountAfterFee = _spendParams.revealedAmount - poolFee;
        require(_spendParams.broadcasterFee <= revealedAmountAfterFee, "More fee than revealed!");

        uint256 rootCoin = coinSource[_spendParams.coin];
        uint256 extraCommitment =
            uint256(keccak256(abi.encodePacked(_spendParams.broadcasterFee, _spendParams.receiver))) >> 8;
        require(rootCoin != 0, "Coin does not exist");
        require(coinSource[_spendParams.remainingCoin] == 0, "Remaining coin already exists");
        uint256 commitment =
            uint256(
                    keccak256(
                        abi.encodePacked(
                            _spendParams.coin, _spendParams.revealedAmount, _spendParams.remainingCoin, extraCommitment
                        )
                    )
                ) >> 8;
        require(
            spendVerifier.verifyProof(_spendParams.pA, _spendParams.pB, _spendParams.pC, [commitment]), "Invalid proof!"
        );

        coinSource[_spendParams.coin] = 0;
        coinSource[_spendParams.remainingCoin] = rootCoin;
        coinRevealed[rootCoin] += _spendParams.revealedAmount;
        require(coinRevealed[rootCoin] <= MINT_CAP, "Mint is capped!");

        // STATE CHANGES
        _mint(msg.sender, _spendParams.broadcasterFee);
        _mint(_spendParams.receiver, revealedAmountAfterFee - _spendParams.broadcasterFee);
        mintForRewardPool(poolFee);
    }
}
