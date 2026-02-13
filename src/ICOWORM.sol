// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ICOWORM is ERC20, Ownable {
    // Mapping to track allowed senders
    mapping(address => bool) private _allowedSenders;

    event SenderAllowed(address indexed account);
    event SenderRemoved(address indexed account);

    constructor() ERC20("ICOWORM", "ICOWORM") Ownable(msg.sender) {
        _allowedSenders[address(0)] = true; // To allow premint
        _mint(msg.sender, 1_170_335.414128736795616549 ether);
        _allowedSenders[address(0)] = false;

        _allowedSenders[msg.sender] = true; // Owner allowed by default
    }

    // Modifier to restrict transfers
    modifier onlyAllowedSender(address from) {
        require(_allowedSenders[from], "Sender not allowed to transfer");
        _;
    }

    // Owner can allow address
    function allowSender(address account) external onlyOwner {
        _allowedSenders[account] = true;
        emit SenderAllowed(account);
    }

    // Owner can remove address
    function removeSender(address account) external onlyOwner {
        _allowedSenders[account] = false;
        emit SenderRemoved(account);
    }

    function isAllowed(address account) external view returns (bool) {
        return _allowedSenders[account];
    }

    // Override internal transfer hook
    function _update(address from, address to, uint256 value) internal override onlyAllowedSender(from) {
        super._update(from, to, value);
    }
}
