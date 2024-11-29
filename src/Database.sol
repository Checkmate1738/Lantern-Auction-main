//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Auction} from "./Auction.sol";

enum IsRegistered {
    notRegistered,
    registered
}

enum AuctionStatus {
    isOpen,
    isClosed,
    pending
}

enum Escrow {
    hasVault,
    noVault
}

enum DepositStatus {
    hasDeposited,
    noDeposit
}

enum WithdrawStatus {
    hasWithdrawn,
    noWithdraw
}

enum Exchange {
    exchangeDone,
    noExchange
}

enum Duration {
    Day,
    Week,
    Month
}

event AuctionLaunched(address indexed auction, uint256 startTime, uint256 stopTime);
event NewBidder(address indexed bidder);
event NFT_Transfered(address indexed tokenAddress, address to, uint256 amount, uint256 tokenId);
event BidPlaced(address indexed bidder, uint256 amount);

struct Auctions {
    bytes3 auctionSig_;
    address auctionAddress_;
    string auctionName_;
}

struct Vault {
    uint256 amount_;
    bytes32 accessKey_;
}

struct nft {
    address nftAddress;
    address owner;
}

struct Asset {
    uint256 id_;
    address nftAddress_;
    uint256 initAmount_;
    uint256 currentAmount_;
}

struct Bid {
    address buyer_;
    uint256 amount_;
}
    
struct Bidder {
    address buyer_;
    DepositStatus deposit_;
    WithdrawStatus withdraw_;
    Escrow safe_;
    IsRegistered registered_;
}

struct Seller {
    address seller_;
    DepositStatus deposit_;
    WithdrawStatus withdraw_;
    Escrow safe_;
    Asset asset_;
}

struct ManagerID{
    address manager;
    uint256 id;
    bool isManager;
}

function _setDuration_(Duration _duration) pure returns(uint256){
        
    if (_duration == Duration.Day){
        return 1 days;
    } else if (_duration == Duration.Week){
        return 1 weeks;
    } else if (_duration == Duration.Month){
        return 4 weeks;
    } else {
        revert("Invalid duration");
    }
}