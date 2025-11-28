// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Dutch is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    event Purchased(address indexed buyer, uint256 amount, uint256 price, uint256 change);

    /// @notice ERC20 token being sold in this Dutch auction.
    IERC20 public token;

    /// @notice Timestamp when the auction begins.
    uint256 startTime;

    /// @notice Starting price of the token (highest price).
    uint256 initialPrice;

    /// @notice Amount the price decreases per second.
    uint256 priceDecreasePerSecond;

    /// @notice Minimum price the auction can reach.
    uint256 minPrice;

    constructor(
        address _owner,
        IERC20 _token,
        uint256 _startTime,
        uint256 _initialPrice,
        uint256 _priceDecreasePerSecond,
        uint256 _minPrice
    ) Ownable(_owner) {
        token = _token;
        startTime = _startTime;
        initialPrice = _initialPrice;
        priceDecreasePerSecond = _priceDecreasePerSecond;
        minPrice = _minPrice;
    }

    /**
     * @notice Returns the current token price based on elapsed time.
     *         Price decays linearly from initialPrice down to minPrice.
     *         Reverts if called before the auction starts.
     */
    function currentPrice() public view returns (uint256) {
        require(block.timestamp >= startTime, "Auction has not yet begun!");
        uint256 elapsed = block.timestamp - startTime;
        uint256 maxDecay = initialPrice - minPrice;
        uint256 decay = Math.min(elapsed * priceDecreasePerSecond, maxDecay);
        return initialPrice - decay;
    }

    /**
     * @notice Finalizes the auction.
     *         - Can only be called once price has fully decayed to minPrice.
     *         - Sends all collected ETH and remaining tokens to the owner.
     *         NOTE: Does NOT require that all tokens be sold.
     */
    function finalize() external nonReentrant {
        require(currentPrice() == minPrice, "Auction has not yet ended!");
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
    function buy() external payable nonReentrant {
        uint256 price = currentPrice();
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
