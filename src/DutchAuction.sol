// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract DutchAuction is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    event Purchased(address indexed buyer, uint256 amount, uint256 price, uint256 change);

    /// @notice ERC20 token being sold in this Dutch auction.
    IERC20 public token;

    /// @notice Number of tokens to be sold.
    uint256 public amountForSale;

    /// @notice Timestamp when the auction begins.
    uint256 public startTime;

    /// @notice Starting price of the token (highest price).
    uint256 public initialPrice;

    /// @notice Amount the price decreases per second.
    uint256 public priceDecreasePerSecond;

    modifier onlyInitialized() {
        require(amountForSale != 0, "Auction not initialized!");
        _;
    }

    constructor(
        address _owner,
        IERC20 _token,
        uint256 _startTime,
        uint256 _initialPrice,
        uint256 _priceDecreasePerSecond
    ) Ownable(_owner) {
        token = _token;
        startTime = _startTime;
        initialPrice = _initialPrice;
        priceDecreasePerSecond = _priceDecreasePerSecond;
    }

    /**
     * @notice Returns the current token price based on elapsed time.
     *         Price decays linearly from initialPrice down to 0.
     *         Reverts if called before the auction starts.
     */
    function currentPrice() public view returns (uint256) {
        require(block.timestamp >= startTime, "Auction has not yet begun!");
        uint256 elapsed = block.timestamp - startTime;
        return initialPrice - Math.min(elapsed * priceDecreasePerSecond, initialPrice);
    }

    /**
     * @notice Deposits.
     *         Price decays linearly from initialPrice down to 0.
     *         Reverts if called before the auction starts.
     */
    function initialize(uint256 _amount) external onlyOwner {
        require(amountForSale == 0, "Already initialized!");
        require(_amount > 0, "No tokens deposited!");
        token.safeTransferFrom(msg.sender, address(this), _amount);
        amountForSale = _amount;
    }

    /**
     * @notice Finalizes the auction.
     *         - Can only be called once price has decayed to 0.
     *         - Sends all collected ETH and remaining tokens to the owner.
     *         NOTE: Does NOT require that all tokens be sold.
     */
    function finalize() external nonReentrant onlyInitialized {
        require(currentPrice() == 0, "Auction has not yet ended!");
        uint256 amount = address(this).balance;
        (bool success,) = owner().call{value: amount}("");
        require(success, "Transfer failed");
        uint256 leftover = token.balanceOf(address(this));
        token.safeTransfer(owner(), leftover);
    }

    /**
     * @notice Allows users to buy tokens at the current price.
     *         - Calculates how many tokens msg.value can buy.
     *         - Refunds any unused ETH.
     * @dev Uses integer division: msg.value / price truncates.
     */
    function buy() external payable nonReentrant onlyInitialized {
        uint256 price = currentPrice();
        require(price > 0, "Price has reached zero!");
        uint256 tokensLeft = token.balanceOf(address(this));
        require(tokensLeft > 0, "No token left!");
        uint256 bought = Math.min(msg.value / price, tokensLeft);
        uint256 change = msg.value - bought * price;
        if (change > 0) {
            (bool success,) = msg.sender.call{value: change}("");
            require(success, "Cannot give back remainder!");
        }
        token.safeTransfer(msg.sender, bought);
        emit Purchased(msg.sender, bought, price, change);
    }
}
