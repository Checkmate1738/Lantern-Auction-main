//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";
import "./Database.sol";

contract Auction {

    uint256 private immutable startTime;
    uint256 private immutable stopTime;
    address internal immutable currency;
    address internal immutable manager;

    uint8 constant maxBidders = type(uint8).max;
    uint8 internal _totalBidders_;
    uint8 internal _totalBids_;

    Seller private seller;
    Asset private asset;
    uint256 internal finalAmount;
    Bid private _highestBidder_;
    AuctionStatus private status;


    mapping(address => Bidder) private bidder;
    mapping(address => Vault) private safe;
    mapping(address => Bid[]) private bids;

    constructor (
        address _seller,
        address _manager,
        address _currency,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _initAmount,
        uint256 _startTime,
        uint256 _stopTime,
        bytes10 _accessKey
    ) {
        require(_seller != address(0), "AUCTION ERROR : Invalid EOA address" );
        require(IERC20(_currency).balanceOf(_seller) >= ( _initAmount + 1 ether ), "AUCTION ERROR : Insufficient funds for auction");
        require(IERC721(_tokenAddress).ownerOf(_tokenId) == _seller, "AUCTION ERROR : Not an owner in the NFT" );
        require(_stopTime > _startTime, "AUCTION ERROR : Auction time can't be the same.");

        asset = Asset({
            id_ : _tokenId,
            nftAddress_ : _tokenAddress,
            initAmount_ : _initAmount,
            currentAmount_ : _initAmount
        });

        safe[_seller] = Vault({
            amount_ : _initAmount,
            accessKey_ : _accessKey
        });

        seller = Seller({
            seller_ : _seller,
            deposit_ : DepositStatus.hasDeposited,
            withdraw_ : WithdrawStatus.noWithdraw,
            safe_ : Escrow.hasVault,
            asset_ : asset
        });

        manager = _manager;
        currency = _currency;
        startTime = block.timestamp + _startTime;
        stopTime = startTime + _stopTime;
        
        IERC721(_tokenAddress).approve(msg.sender, _tokenId);
        IERC20(_currency).approve(msg.sender,_initAmount);

        IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
        require(IERC20(_currency).transferFrom(msg.sender, address(this), _initAmount),"AUCTION ERROR : No deposit was done");
        emit AuctionLaunched(address(this), startTime, stopTime);
    }

/* 
        MODIFIERS    
*/

    modifier afterAuction() {
        require(status == AuctionStatus.isClosed, "AUCTION ERROR : Auctioned is still open");
        _;
    }

    modifier onGoingAuction() {
        require(status == AuctionStatus.isOpen, "AUCTION ERROR : Auctioned is closed" );
        _;
    }

    modifier notRegistered(address _address) {
        require(bidder[_address].registered_ == IsRegistered.notRegistered,"AUCTION ERROR : Already registered");
        require(_totalBidders_ <= maxBidders, "AUCTION ERROR : Maximum limit achieved");
        _;
    }

    modifier onlySeller() {
        require(seller.seller_ == msg.sender, "AUCTION ERROR : Access Denied");
        _;
    }

    modifier registered(address _address) {
        require(bidder[_address].buyer_ == _address, "AUCTION ERROR : Not yet registered");
        _;
    }

    modifier onlyBidders(address _address) {
        require(bidder[_address].registered_ == IsRegistered.registered, "AUCTION ERROR : Account not registered");
        require(bidder[_address].deposit_ == DepositStatus.hasDeposited,"AUCTION ERROR : Make a deposit before biding");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == manager);
        _;
    }

/*
        END OF MODIFIERS
*/

    function register(
        address _buyer,
        uint256 _minDeposit,
        bytes10 _accessKey
    ) public notRegistered(msg.sender) {
        require(_minDeposit > 10 , "AUCTION ERROR : To be registered, you have to put more than $10");
        
        safe[msg.sender] = Vault({
            amount_ : _minDeposit,
            accessKey_ : _accessKey
        });
        
        bidder[msg.sender] = Bidder({
            buyer_ : _buyer,
            deposit_ : DepositStatus.hasDeposited,
            withdraw_ : WithdrawStatus.hasWithdrawn,
            safe_ : Escrow.hasVault,
            registered_ : IsRegistered.registered
        });

        _totalBidders_ ++;
        
        emit NewBidder(msg.sender);
    }

    function placeBid(uint256 _amount) public onGoingAuction onlyBidders(msg.sender) {
        require(_amount > asset.currentAmount_,"AUCTION ERROR : Below current bid");
        require(safe[msg.sender].amount_ >= _amount,"AUCTION ERROR : Insufficient funds, kindly top-up");
        
        if (bids[msg.sender].length != 0 ) {
            bids[msg.sender].push(Bid({
                buyer_ : msg.sender,
                amount_ : _amount
            }));
            asset.currentAmount_ = _amount;
            _totalBids_ ++;
        }else {
            bids[msg.sender].push(Bid({
                buyer_ : msg.sender,
                amount_ : _amount
            }));
            _totalBids_ ++;
            asset.currentAmount_ = _amount;
        }

        _highestBidder_ = Bid({
            buyer_ : msg.sender,
            amount_ : _amount
        });

        emit BidPlaced(msg.sender,_amount);
    }

    function deposit(uint256 _amount,bytes10 _accessKey) onGoingAuction registered(msg.sender) public {
        require(_accessKey == safe[msg.sender].accessKey_, "AUCTION ERROR : Invalid access key");
        require(bidder[msg.sender].withdraw_ == WithdrawStatus.noWithdraw,"AUCTION ERROR : already withdrew");
        
        safe[msg.sender].amount_ = _amount;
        bidder[msg.sender].withdraw_ = WithdrawStatus.noWithdraw;
        bidder[msg.sender].deposit_ = DepositStatus.hasDeposited;
        bidder[msg.sender].safe_ = Escrow.hasVault;
        
        require(IERC20(currency).transfer(address(this), _amount),"AUCTION ERROR : Transfer completed unsuccessfully");
    }

    function withdraw(bytes10 _accessKey) afterAuction onlyBidders(msg.sender) public {
        require(_accessKey == safe[msg.sender].accessKey_, "AUCTION ERROR : Invalid access key");
        require(bidder[msg.sender].withdraw_ == WithdrawStatus.noWithdraw,"AUCTION ERROR : already withdrew");
        
        uint256 amount = safe[msg.sender].amount_;
        delete safe[msg.sender];
        bidder[msg.sender].withdraw_ = WithdrawStatus.hasWithdrawn;
        bidder[msg.sender].deposit_ = DepositStatus.noDeposit;
        bidder[msg.sender].safe_ = Escrow.noVault;
        
        require(IERC20(currency).transferFrom(address(this),msg.sender,amount), "AUCTION ERROR : Transfer completed unsuccessfully");
    }

    function sendNFT() afterAuction onlySeller public {
        require(IERC20(currency).transferFrom(_highestBidder_.buyer_, seller.seller_, _highestBidder_.amount_),"AUCTION ERROR : Transfer completed Unsuccessfully");
        IERC721(asset.nftAddress_).safeTransferFrom(address(this), _highestBidder_.buyer_, asset.id_);
        emit NFT_Transfered(asset.nftAddress_,_highestBidder_.buyer_,_highestBidder_.amount_,asset.id_);
        delete asset;
    }

    function totalBids() public view returns(uint8) {
        return _totalBids_;
    }

    function totalBidders() public view returns(uint8) {
        return _totalBidders_;
    }

    function myAccount() onGoingAuction registered(msg.sender) public view returns(Bidder memory) {
        return bidder[msg.sender];
    }

    function myBids() public view onGoingAuction onlyBidders(msg.sender) returns(Bid[] memory) {
        return bids[msg.sender];
    }

    function final_amount() afterAuction view public returns(uint256){
        return finalAmount;
    }

    function highestBidder() public view returns(address) {
        return _highestBidder_.buyer_;
    }

    function execSend() afterAuction public onlyManager {
        require(IERC20(currency).transferFrom(_highestBidder_.buyer_, msg.sender, _highestBidder_.amount_),"AUCTION ERROR : Transfer completed Unsuccessfully");
        IERC721(asset.nftAddress_).safeTransferFrom(address(this), _highestBidder_.buyer_, asset.id_);
        emit NFT_Transfered(asset.nftAddress_,_highestBidder_.buyer_,_highestBidder_.amount_,asset.id_);
        finalAmount = _highestBidder_.amount_;
        delete asset;
    }

    receive() external payable {
        revert("AUCTION ERROR: Contract does not accept Ether");
    }
    
} 