// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract KOLNetwork is Ownable {
    IERC20 public immutable wormToken;

    uint256 public constant SIGNUP_COST = 1e17; // 1 WORM (assuming 18 decimals)
    uint256 public maxRootChildren;
    uint256 public maxOtherChildren; // Max direct children per KOL

    struct KOL {
        address parent;
        bool isKOL;
        uint256 childCount;
        string inviteCode;
        string metadata;
    }

    mapping(address => KOL) public kols;
    mapping(string => address) public codeToKOL; // invite code → KOL address

    event RootKOLAdded(address indexed kol, string inviteCode);
    event Participated(
        address indexed user,
        address indexed parent,
        string userCode,
        string parentCode,
        bool transferWorm,
        string metadata
    );
    event TokensWithdrawn(address indexed to, uint256 amount);
    event MaxChildrenUpdated(uint256 newLimit);

    constructor(address _wormToken, uint256 _maxRootChildren, uint256 _maxOtherChildren) Ownable(msg.sender) {
        require(_wormToken != address(0), "Invalid WORM token");
        wormToken = IERC20(_wormToken);
        maxRootChildren = _maxRootChildren;
        maxOtherChildren = _maxOtherChildren;
    }

    // --- OWNER FUNCTIONS ---

    function addRootKOL(address kol, string calldata code, string calldata metadata) external onlyOwner {
        require(kol != address(0), "Invalid address");
        require(!kols[kol].isKOL, "Already a KOL");
        require(codeToKOL[code] == address(0), "Code already used");

        kols[kol] = KOL({parent: address(0), isKOL: true, childCount: 0, inviteCode: code, metadata: metadata});
        codeToKOL[code] = kol;

        emit RootKOLAdded(kol, code);
    }

    function setMaxRootChildren(uint256 _maxChildren) external onlyOwner {
        maxRootChildren = _maxChildren;
        emit MaxChildrenUpdated(_maxChildren);
    }

    function setMaxOtherChildren(uint256 _maxChildren) external onlyOwner {
        maxOtherChildren = _maxChildren;
        emit MaxChildrenUpdated(_maxChildren);
    }

    // --- PARTICIPATION FUNCTION ---
    /// @param parentCode the invite code of the KOL who invited the user
    /// @param userCode the unique invite code the new KOL wants to register
    function participate(
        string calldata parentCode,
        string calldata userCode,
        string calldata metadata,
        bool transferWorm
    ) external {
        require(!kols[msg.sender].isKOL, "Already a KOL");
        require(bytes(userCode).length > 0, "Empty code not allowed");
        require(codeToKOL[userCode] == address(0), "Code already taken");

        address parentKOL = codeToKOL[parentCode];
        require(parentKOL != address(0), "Invalid invite code");
        require(kols[parentKOL].isKOL, "Parent not a valid KOL");

        if (kols[parentKOL].parent == address(0)) {
            require(kols[parentKOL].childCount < maxRootChildren, "Parent reached max children");
        } else {
            require(kols[parentKOL].childCount < maxOtherChildren, "Parent reached max children");
        }

        if (transferWorm) {
            require(wormToken.transferFrom(msg.sender, address(this), SIGNUP_COST), "WORM transfer failed");
        }

        // Register new KOL with own code
        kols[msg.sender] =
            KOL({parent: parentKOL, isKOL: true, childCount: 0, inviteCode: userCode, metadata: metadata});
        codeToKOL[userCode] = msg.sender;

        // Increment parent’s child count
        kols[parentKOL].childCount++;

        emit Participated(msg.sender, parentKOL, userCode, parentCode, transferWorm, metadata);
    }
}
