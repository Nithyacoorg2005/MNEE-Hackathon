// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; 
import "./RetentionScore.sol"; 

contract RetentionRelay is Ownable, ReentrancyGuard {
    IERC20 public immutable MNEE;

    // --- Events (Omitted for brevity) ---
    struct Escrow {
        address user;
        address merchant;
        uint256 amount; 
        uint256 matchAmount;
        uint256 unlockTime;
        uint256 vestingMonths;
        bool claimed;
    }
    struct Offer {
        address publisher;
        uint256 newAmount; 
        uint256 expiresAt;
    }
    event EscrowCreated(bytes32 indexed escrowId, address indexed user, address indexed merchant, uint256 amount, uint256 matchAmount, uint256 unlockTime, uint256 vestingMonths);
    event OfferClaimed(bytes32 indexed escrowId, address indexed merchant, uint256 paidAmount, uint256 usedMatchAmount, uint256 protocolMatchRefund, uint256 userRefund);
    event EscrowWithdrawn(bytes32 indexed escrowId, address indexed user);

    mapping(bytes32 => Escrow) public escrows;
    mapping(bytes32 => Offer) public offers;

    uint256 public matchPool; 
    RetentionScore public scoreToken;

    // FIX: Accept initialOwner and pass it to Ownable constructor
    constructor(address _mnee, address initialOwner) 
        Ownable(initialOwner) 
    {
        MNEE = IERC20(_mnee);
        scoreToken = new RetentionScore(address(this), initialOwner); 
    }

    function fundMatchPool(uint256 amount) external nonReentrant onlyOwner {
        require(amount > 0, "amount=0");
        require(MNEE.transferFrom(msg.sender, address(this), amount), "transferFrom failed"); 
        matchPool += amount;
    }

    function createEscrow(bytes32 escrowId, address merchant, uint256 amount, uint256 unlockTime, uint256 matchRequested, uint256 vestingMonths) external nonReentrant {
        require(escrows[escrowId].user == address(0), "escrow exists");
        require(amount > 0, "amount=0");
        require(merchant != address(0), "merchant=0");

        require(MNEE.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        uint256 matchAllocated = 0;
        if (matchRequested > 0) {
            uint256 available = matchPool;
            if (available > 0) {
                matchAllocated = matchRequested <= available ? matchRequested : available;
                matchPool -= matchAllocated;
            }
        }

        escrows[escrowId] = Escrow({
            user: msg.sender,
            merchant: merchant,
            amount: amount,
            matchAmount: matchAllocated,
            unlockTime: unlockTime,
            vestingMonths: vestingMonths,
            claimed: false
        });

        if (!scoreToken.hasToken(msg.sender)) {
            scoreToken.mintScore(msg.sender);
        }

        emit EscrowCreated(escrowId, msg.sender, merchant, amount, matchAllocated, unlockTime, vestingMonths);
    }

    function publishOffer(bytes32 escrowId, uint256 discountBps, uint256 newAmount, uint256 expiresAt) external nonReentrant {
        Escrow storage e = escrows[escrowId];
        require(e.user != address(0), "escrow missing");
        require(msg.sender == e.merchant, "only merchant"); 
        require(expiresAt > block.timestamp, "expiresAt in past");

        uint256 totalAtRisk = e.amount + e.matchAmount;
        require(newAmount <= totalAtRisk, "newAmount > total at risk");

        offers[escrowId] = Offer({publisher: msg.sender, newAmount: newAmount, expiresAt: expiresAt});
    }

    function claimOffer(bytes32 escrowId) external nonReentrant {
        Escrow storage e = escrows[escrowId];
        Offer storage o = offers[escrowId];
        require(e.user != address(0), "escrow missing");
        require(o.publisher == msg.sender, "only publisher");
        require(block.timestamp <= o.expiresAt, "offer expired");
        require(!e.claimed, "already claimed");

        uint256 totalAtRisk = e.amount + e.matchAmount;
        uint256 paidToMerchant = o.newAmount;

        uint256 usedMatchAmount = 0;
        if (paidToMerchant > e.amount) {
            usedMatchAmount = paidToMerchant - e.amount;
        } else {
            usedMatchAmount = 0;
        }

        uint256 protocolMatchRefund = e.matchAmount - usedMatchAmount; 
        uint256 userRefund = totalAtRisk - paidToMerchant - protocolMatchRefund;

        e.claimed = true;

        if (protocolMatchRefund > 0) {
            matchPool += protocolMatchRefund;
        }

        require(MNEE.transfer(msg.sender, paidToMerchant), "transfer to merchant failed");

        if (userRefund > 0) {
            require(MNEE.transfer(e.user, userRefund), "refund to user failed");
        }

        if (scoreToken.hasToken(e.user)) {
            uint256 tokenId = scoreToken.ownerToToken(e.user);
            scoreToken.decreaseScore(tokenId, 1); 
        }

        emit OfferClaimed(escrowId, msg.sender, paidToMerchant, usedMatchAmount, protocolMatchRefund, userRefund);
    }

    function withdrawEscrow(bytes32 escrowId) external nonReentrant {
        Escrow storage e = escrows[escrowId];
        require(e.user == msg.sender, "only user");
        require(!e.claimed, "already claimed");
        require(block.timestamp >= e.unlockTime, "not unlocked yet");

        e.claimed = true;

        uint256 refund = e.amount;
        if (refund > 0) {
            require(MNEE.transfer(e.user, refund), "refund failed");
        }

        if (e.matchAmount > 0) {
            matchPool += e.matchAmount;
        }

        emit EscrowWithdrawn(escrowId, e.user);
    }
}