//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "./Database.sol";
import {Auction} from "./Auction.sol";
import {USDT} from "./USDT.sol";
import {NFT} from "./NFT.sol";

contract Lobby {
    
    address internal immutable PRESIDENT;
    address[] internal manager;
    Auctions[] internal archive;
    nft[] internal availableNFTs;
    USDT internal currency;

    // Auctions Per Seller (APS)
    mapping(address => Auctions[]) internal APS;
    mapping(address => bool) internal sellers;
    mapping(address manager => bool ) internal managers;
    mapping(bytes3 auctionSig => Auction auction_) internal auctions;
    mapping(address NFT_Owner => mapping(address NFT_Address => NFT _NFT_ )) internal NFTs;

    constructor () {
        PRESIDENT = msg.sender;
        currency = new USDT();
    }

    modifier onlySellers() {
        require(sellers[msg.sender], "AUCTION ERROR : Forbidden, Not a seller");
        _;
    }

    modifier onlyPRESIDENT() {
        require(msg.sender == PRESIDENT, "Not a President");
        _;
    }

    modifier onlyManager() {
        require(managers[msg.sender], "Not a manager");
        _;
    }

    function newAuction(
        address seller,
        string memory auctionName,
        address tokenAddress,
        uint256 tokenId,
        uint256 initAmount,
        bytes10 accessKey,
        Duration _startTime_,
        Duration _stopTime_,
        uint8 _manager
    ) payable public returns(address) {
        uint256 startTime = _setDuration_(_startTime_);
        uint256 stopTime = _setDuration_(_stopTime_);

        Auction auction = new Auction(
            seller,
            manager[_manager],
            address(currency),
            tokenAddress,
            tokenId,
            initAmount,
            startTime,
            stopTime,
            accessKey
        );

        sellers[msg.sender] = true;

        bytes3 auctionSig = bytes3(keccak256(abi.encode(auctionName)));

        archive.push(
            Auctions({
                auctionSig_ : auctionSig,
                auctionAddress_ : address(auction),
                auctionName_ : auctionName
            })
        );

        APS[msg.sender].push(
            Auctions({
                auctionSig_ : auctionSig,
                auctionAddress_ : address(auction),
                auctionName_ : auctionName
            })
        );

        auctions[auctionSig] = auction;
        return seller;
    }

    function myAuctions() public onlySellers view returns (Auctions[] memory){
        return APS[msg.sender];
    }

/*
        INTERACTIONS WITH AUCTIONS
*/

    function Registration(bytes3 _auctionSig_, uint256 amount, bytes10 accessKey) public {
        Auction auction = auctions[_auctionSig_];
        auction.register(msg.sender, amount, accessKey);
    }

    function place_Bid(bytes3 _auctionSig_, uint256 amount) public {
        Auction auction = auctions[_auctionSig_];
        auction.placeBid(amount);
    }

    function Deposit(bytes3 _auctionSig_, uint256 amount, bytes10 accessKey) public {
        Auction auction = auctions[_auctionSig_];
        auction.deposit(amount, accessKey);
    }

    function Withdraw(bytes3 _auctionSig_,bytes10 accessKey) public {
        Auction auction = auctions[_auctionSig_];
        auction.withdraw(accessKey);
    }

    function SendAsset(bytes3 _auctionSig_) onlySellers public{
        Auction auction = auctions[_auctionSig_];
        auction.sendNFT();
    }

    function ExecutiveSend(bytes3 _auctionSig_) onlyManager public {
        Auction auction = auctions[_auctionSig_];
        auction.execSend();
    }

/*
        END OF INTERACTIONS WITH AUCTIONS
*/

/*
        Administrative management
*/

    function AddManager(address _address) public onlyPRESIDENT {
        managers[_address] = true;
    }

    function RemoveManager(address _address) public onlyPRESIDENT {
        managers[_address] = false;
    }

/*
        End of Administrative management
*/

/*
        NFT Department
*/

    function createNFT(string memory name, string memory symbol,uint256 size) public returns(nft memory){
        require(size <= 10, "Maximum amount of tokens reached");
        NFT _NFT_ = new NFT(name,symbol);
        NFTs[msg.sender][address(_NFT_)] = _NFT_;
        for (uint i = 0; i < size ; ++i) {
            _NFT_.mint();
        }
        nft memory __NFT = nft({
            nftAddress : address(_NFT_),
            owner : msg.sender
        });
        availableNFTs.push(__NFT);
        return __NFT;
    }

/*
        End of NFT Department
*/

    function generateKey(uint256 _hash, uint256 salt) pure public returns(bytes32){
        return bytes10(keccak256(abi.encode(_hash + salt)));
    }

    function buyUSDT() payable public {
        (bool success, ) = address(currency).call{value:msg.value}(abi.encodeWithSelector(0xd0e30db0, ""));
        require(success,"Purchase unsuccessful");
    }

    function sellUSDT() payable public {
        (bool success, ) = address(currency).call{value:msg.value}(abi.encodeWithSelector(0x3ccfd60b, ""));
        require(success,"Sell unsuccessful");
    }

    
}
