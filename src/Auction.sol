//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";
import "./Database.sol";

contract Auction is IERC721Receiver{

    uint256 private immutable startTime;
    uint256 private immutable stopTime;
    address internal immutable currency;

    uint256 internal finalAmount;
    uint8 constant maxBidders = type(uint8).max;
    uint8 internal _totalBidders_;
    uint8 internal _totalBids_;

    Seller private seller;
    Asset public asset;
    Bid private _highestBidder_;
    AuctionStatus private status;


    mapping(address => Bidder) private bidder;
    mapping(address => Vault) private safe;
    mapping(address => Bid[]) private bids;

    constructor (
        address _currency,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _initAmount,
        uint256 _startTime,
        uint256 _stopTime,
        bytes10 _accessKey
    ) {
        require(msg.sender != address(0), "AUCTION ERROR : Invalid EOA address" );
        require(IERC20(_currency).balanceOf(msg.sender) >= ( _initAmount + 1 ether ), "AUCTION ERROR : Insufficient funds for auction");
        require(IERC721(_tokenAddress).ownerOf(_tokenId) == msg.sender, "AUCTION ERROR : Not an owner in the NFT" );
        require(block.timestamp < _startTime,"AUCTION ERROR : Can't start an auction immediately after launch");
        require(_stopTime > _startTime, "AUCTION ERROR : Auction time can't be the same.");

        asset = Asset({
            id_ : _tokenId,
            nftAddress_ : _tokenAddress,
            initAmount_ : _initAmount,
            currentAmount_ : _initAmount
        });

        safe[msg.sender] = Vault({
            amount_ : _initAmount,
            accessKey_ : _accessKey
        });

        seller = Seller({
            seller_ : msg.sender,
            deposit_ : DepositStatus.hasDeposited,
            withdraw_ : WithdrawStatus.noWithdraw,
            safe_ : Escrow.hasVault,
            asset_ : asset
        });

        currency = _currency;
        startTime = block.timestamp + _startTime;
        stopTime = startTime + _stopTime;
        status = AuctionStatus.pending;

        emit AuctionLaunched(address(this), _startTime, block.timestamp + _stopTime);
    }

/* 
        MODIFIERS    
*/

    modifier afterAuction() {
        _update();
        require(status == AuctionStatus.isClosed, "AUCTION ERROR : Auction is still open");
        _;
    }

    modifier onGoingAuction() {
        _update();
        require(status == AuctionStatus.isOpen, "AUCTION ERROR : Auction is closed" );
        _;
    }

    modifier beforeAuction() {
        _update();
        require(status == AuctionStatus.pending, "AUCTION ERROR : Auction is open" );
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

/*
        END OF MODIFIERS
*/

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector; // Return correct magic value
    }

    function MinAmt() public onlySeller beforeAuction {
        uint256 amount = safe[msg.sender].amount_;
        require(IERC20(currency).transferFrom(msg.sender, address(this), amount),"AUCTION ERROR : No deposit was done");
    }

    function register(
        uint256 _minDeposit,
        bytes10 _accessKey
    ) public notRegistered(msg.sender) {
        require(_minDeposit > 10 , "AUCTION ERROR : To be registered, you have to put more than $10");

        safe[msg.sender] = Vault({
            amount_ : _minDeposit,
            accessKey_ : _accessKey
        });
        
        bidder[msg.sender] = Bidder({
            buyer_ : msg.sender,
            deposit_ : DepositStatus.hasDeposited,
            withdraw_ : WithdrawStatus.noWithdraw,
            safe_ : Escrow.hasVault,
            registered_ : IsRegistered.registered
        });

        _totalBidders_ ++;
        
        require(IERC20(currency).transferFrom(msg.sender,address(this), _minDeposit),"AUCTION ERROR : Insufficient allowance");

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
        
        require(IERC20(currency).transferFrom(msg.sender,address(this), _amount),"AUCTION ERROR : Insufficient allowance");
    }

    function withdraw(bytes10 _accessKey) afterAuction onlyBidders(msg.sender) public {
        require(_accessKey == safe[msg.sender].accessKey_, "AUCTION ERROR : Invalid access key");
        require(bidder[msg.sender].withdraw_ == WithdrawStatus.noWithdraw,"AUCTION ERROR : already withdrew");
        require(msg.sender != _highestBidder_.buyer_,"AUCTION ERROR : Can't withdraw you are the current highest bidder");

        uint256 amount = safe[msg.sender].amount_;
        delete safe[msg.sender];
        bidder[msg.sender].withdraw_ = WithdrawStatus.hasWithdrawn;
        bidder[msg.sender].deposit_ = DepositStatus.noDeposit;
        bidder[msg.sender].safe_ = Escrow.noVault;
        
        require(IERC20(currency).transfer(msg.sender,amount), "AUCTION ERROR : Transfer completed unsuccessfully");
    }

    function sendNFT() afterAuction onlySeller public {
        require(IERC20(currency).transfer(seller.seller_, _highestBidder_.amount_),"AUCTION ERROR : Transfer completed Unsuccessfully");
        IERC721(asset.nftAddress_).safeTransferFrom(address(this), _highestBidder_.buyer_, asset.id_);
        emit NFT_Transfered(asset.nftAddress_,_highestBidder_.buyer_,_highestBidder_.amount_,asset.id_);
        delete asset;
    }

    function _update() internal {
        if (block.timestamp < startTime) {
            status = AuctionStatus.pending;
        }
        else if (block.timestamp >= startTime && block.timestamp < stopTime) {
            status = AuctionStatus.isOpen;
        }
        else if (block.timestamp >= stopTime) {
            status = AuctionStatus.isClosed;
        }
    }

    function assetInAuction() view public returns(Asset memory) {
        return asset;
    }

    function totalBids() view public returns(uint8) {
        return _totalBids_;
    }

    function totalBidders() view public returns(uint8) {
        return _totalBidders_;
    }

    function myAccount() onGoingAuction registered(msg.sender) public  returns(Bidder memory) {
        return bidder[msg.sender];
    }

    function myBids() public onGoingAuction onlyBidders(msg.sender) returns(Bid[] memory) {
        return bids[msg.sender];
    }

    function final_amount() afterAuction public returns(uint256){
        return finalAmount;
    }

    function Status() public returns(string memory _status) {
        _update();
        if (status == AuctionStatus.pending) {
            _status = "pending";
        }
        if (status == AuctionStatus.isOpen) {
            _status = "Open";
        }
        if (status == AuctionStatus.isClosed) {
            _status = "closed";
        }
    }

    function highestBidder() public view returns(address) {
        return _highestBidder_.buyer_;
    }

    receive() external payable {
        revert("AUCTION ERROR: Contract does not accept Ether");
    }
    
} 