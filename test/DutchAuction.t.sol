// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/DutchAuction.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DutchAuctionTest is Test {
    DutchAuction auction;
    MockToken token;
    address owner = address(0xA11CE);
    address buyer = address(0xBEEF);
    address buyer2 = address(0xCAFE);

    uint256 startTime;
    uint256 initialPrice = 1 ether;
    uint256 priceDecreasePerSecond = 0.1 ether;

    uint256 initialTokens = 1000 ether;

    function setUp() public {
        token = new MockToken();
        startTime = block.timestamp + 100;
        auction = new DutchAuction(owner, IERC20(address(token)), startTime, initialPrice, priceDecreasePerSecond);
        token.mint(owner, initialTokens);

        vm.prank(owner);
        token.approve(address(auction), initialTokens);

        vm.prank(owner);
        auction.initialize(initialTokens);

        vm.deal(buyer, 1000 ether);
        vm.deal(buyer2, 1000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                           PRICE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertBeforeStart() public {
        vm.expectRevert("Auction has not yet begun!");
        auction.currentPrice();
    }

    function test_InitialPriceAtStart() public {
        vm.warp(startTime);
        assertEq(auction.currentPrice(), initialPrice);
    }

    function test_PriceDecreasesLinearly() public {
        vm.warp(startTime + 5);
        // new price = 1.0 - (5 * 0.1) = 0.5 ether
        assertEq(auction.currentPrice(), 0.5 ether);
    }

    function test_PriceStopsAtMinPrice() public {
        vm.warp(startTime + 1000);
        assertEq(auction.currentPrice(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                           BUYING TESTS
    //////////////////////////////////////////////////////////////*/

    function testBuyTokensExact() public {
        vm.warp(startTime);

        uint256 price = auction.currentPrice();
        uint256 amountToSend = price * 5; // expect to buy 5 tokens

        vm.prank(buyer);
        auction.buy{value: amountToSend}();

        assertEq(token.balanceOf(buyer), 5);
        assertEq(address(auction).balance, amountToSend);
    }

    function testBuyRefundsChange() public {
        vm.warp(startTime);

        uint256 price = auction.currentPrice(); // initially 1 ether
        uint256 msgValue = 5.5 ether; // should buy 5 tokens, refund 0.5

        vm.prank(buyer);
        auction.buy{value: msgValue}();

        assertEq(token.balanceOf(buyer), 5);
        assertEq(address(auction).balance, price * 5); // 5 ether
        assertEq(buyer.balance, 1000 ether - price * 5); // refunded 0.5
    }

    function testBuyCapsAtTokensLeft() public {
        vm.warp(startTime);

        // Remove almost all tokens
        vm.prank(address(auction));
        token.transfer(address(0x1234), initialTokens - 10);

        vm.prank(buyer);
        auction.buy{value: 1000 ether}();

        assertEq(token.balanceOf(buyer), 10);
    }

    function testRevertWhenNoTokensLeft() public {
        vm.warp(startTime);

        vm.prank(address(auction));
        token.transfer(address(0x1234), initialTokens);

        vm.prank(buyer);
        vm.expectRevert("No token left!");
        auction.buy{value: 10 ether}();
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGER TRUNCATION TEST
    //////////////////////////////////////////////////////////////*/

    function testIntegerDivisionTruncation() public {
        vm.warp(startTime);

        vm.prank(buyer);
        auction.buy{value: 1.9 ether}();
        // price = 1 ether => buy 1 token, refund 0.9

        assertEq(token.balanceOf(buyer), 1);
        assertEq(buyer.balance, 1000 ether - 1 ether);
    }
}
