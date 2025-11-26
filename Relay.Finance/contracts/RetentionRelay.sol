// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RetentionScore is ERC721, Ownable { 
    uint256 private _nextId = 1;
    mapping(address => uint256) public ownerToToken;
    mapping(uint256 => uint256) public tokenScore; 

    address public controller;

    modifier onlyController() {
        require(msg.sender == controller, "only controller");
        _;
    }

    // FIX: Pass initialOwner to Ownable constructor
    constructor(address _controller, address initialOwner) 
        ERC721("RetentionScore", "RSCORE") 
        Ownable(initialOwner) 
    {
        controller = _controller;
    }

    function mintScore(address to) external onlyController returns (uint256) {
        require(!hasToken(to), "already has token");
        uint256 id = _nextId++;
        _safeMint(to, id);
        ownerToToken[to] = id;
        tokenScore[id] = 50; 
        return id;
    }

    function hasToken(address who) public view returns (bool) {
        return ownerToToken[who] != 0;
    }

    // FIX: Simplified _transfer function to comply with base ERC721 internal structure
    function _transfer(address from, address to, uint256 tokenId) internal { 
        revert("SBT: non-transferable");
    }

    function approve(address to, uint256 tokenId) public view override {
        revert("SBT: non-transferable");
    }
    function setApprovalForAll(address operator, bool approved) public view override {
        revert("SBT: non-transferable");
    }
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return false;
    }
}