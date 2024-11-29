//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "./Database.sol";
import {Auction} from "./Auction.sol";
import {USDT} from "./USDT.sol";
import {NFT} from "./NFT.sol";

contract Lobby is IERC721Receiver {
    
    address internal immutable PRESIDENT;
    address[] internal manager;
    Auctions[] internal archive;
    nft[] internal availableNFTs;
    USDT internal currency;

    // Auctions Per Seller (APS)
    mapping(address => Auctions[]) internal APS;
    mapping(address => bool) internal sellers;
    mapping(address manager => ManagerID managerId ) internal managers;
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
        require(managers[msg.sender].isManager, "Not a manager");
        _;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector; // Return correct magic value
    }

    function newAuction(
        string memory auctionName,
        address tokenAddress,
        uint256 tokenId,
        uint256 initAmount,
        bytes10 accessKey,
        Duration _startTime_,
        Duration _stopTime_
    ) payable public returns(address) {
        uint256 startTime = _setDuration_(_startTime_);
        uint256 stopTime = _setDuration_(_stopTime_);

        Auction auction = new Auction(
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
        return msg.sender;
    }

    function myAuctions() public onlySellers view returns (Auctions[] memory){
        return APS[msg.sender];
    }

/*
        INTERACTIONS WITH AUCTIONS
*/

    function Registration(bytes3 _auctionSig_, uint256 amount, bytes10 accessKey) public {
        Auction auction = auctions[_auctionSig_];
        auction.register(amount, accessKey);
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

/*
        END OF INTERACTIONS WITH AUCTIONS
*/

/*
        Administrative management
*/

    function AddManager(address _address) public onlyPRESIDENT {
        ManagerID memory managerId = ManagerID({
            manager : _address,
            id : manager.length,
            isManager : true
        });

        manager.push(_address);

        managers[_address] = managerId;
    }

    function RemoveManager(address _address) public onlyPRESIDENT {
        uint256 _manager = managers[_address].id;
        uint256 _lastManager = manager.length - 1;

        (manager[_manager],manager[_lastManager]) = (manager[_lastManager], manager[_manager]);

        manager.pop();

        delete managers[_address];
    }

/*
        End of Administrative management
*/


    function generateKey(uint256 _hash, uint256 salt) pure public returns(bytes32){
        return bytes10(keccak256(abi.encode(_hash + salt)));
    }
    
}
