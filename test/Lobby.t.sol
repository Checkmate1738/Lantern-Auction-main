//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test,console} from "forge-std/Test.sol";
import {Lobby} from "../src/Lobby.sol";
import {NFT} from "../src/NFT.sol";
import {USDT} from "../src/USDT.sol";
import {Auction} from "../src/Auction.sol";
import {Duration,nft,Asset,AuctionStatus} from "../src/Database.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract TestLobby is Test {
    Lobby internal lobby;
    USDT internal currency;

    function setUp() public {
        vm.startPrank(address(2));
        lobby = new Lobby();
        for (uint256 i; i < 8; ++i) {
            uint256 j = i + 100;
            lobby.AddManager(vm.addr(j));
        }
        currency = new USDT();
        vm.stopPrank();
    }

    function test_newAuction() public {

        address sender = vm.addr(3);
        address bidder = vm.addr(6);
        address bidder1 = vm.addr(7);

        deal(sender,100 ether);

        vm.startPrank(sender);

        bytes4 functionSig = bytes4(abi.encode(keccak256("deposit()")));
        uint256 amount = 10 ether;
        (bool ok, ) = address(currency).call{value: amount}(abi.encodeWithSelector(functionSig, ""));
        require(ok,"USDT purchase unsuccessful");
        bytes10 accessKey = bytes10(lobby.generateKey(1e16, 1738));

        NFT _NFT = new NFT("Dodge", "DGE");

        for (uint i; i < 3;++i) {
            _NFT.mint();
        }

        console.log(msg.sender);

        Auction auction = new Auction(
            address(currency),
            address(_NFT),
            1,
            2 ether,
            2 days,
            1 weeks,
            accessKey
        );

        _NFT.transferFrom(sender, address(auction), 1);

        currency.approve(address(auction), 2 ether);

        auction.MinAmt();

        console.log("sender",currency.balanceOf(sender)); 

        vm.stopPrank();

        console.log(auction.Status());

        vm.warp(3 days);

        console.log(auction.Status());

/*
logic of code
*/

        deal(bidder, 100 ether);
        deal(bidder1, 100 ether);

        vm.startPrank(bidder);
        (bool okay, ) = address(currency).call{value:15 ether}(abi.encodeWithSelector(bytes4(abi.encode(keccak256("deposit()"))),""));
        require(okay,"Unsuccessful");

        console.log("bidder",currency.balanceOf(bidder));

        currency.approve(address(auction), 10 ether);

        auction.register(7 ether, bytes10(abi.encode(keccak256("no soul"))));
        auction.placeBid(4 ether);

        vm.stopPrank();

        vm.startPrank(bidder1);
        (bool okay1, ) = address(currency).call{value:15 ether}(abi.encodeWithSelector(bytes4(abi.encode(keccak256("deposit()"))),""));
        require(okay1,"Unsuccessful");

        console.log("bidder",currency.balanceOf(bidder1));

        currency.approve(address(auction), 10 ether);

        auction.register(5 ether, bytes10(abi.encode(keccak256("soul"))));
        auction.placeBid(5 ether);

        vm.stopPrank();

        vm.prank(bidder);
        auction.placeBid(6 ether);

        console.log(currency.balanceOf(bidder));

        vm.warp(3 weeks);

        vm.prank(bidder1);
        auction.withdraw(bytes10(abi.encode(keccak256("soul"))));

        vm.prank(sender);
        auction.sendNFT();

        Asset memory asset = auction.assetInAuction();

        console.log("sender",currency.balanceOf(sender)); 
        console.log("bidder",currency.balanceOf(bidder)); 

/*
end of logic code
*/
        vm.warp(3 days);

        vm.prank(bidder1);
        auction.myAccount();
        
    }
}
