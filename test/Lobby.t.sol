//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test,console} from "forge-std/Test.sol";
import {Lobby} from "../src/Lobby.sol";
import {Duration,nft} from "../src/Database.sol";

/*
        address seller,
        string auctionName,
        address tokenAddress,
        uint256 tokenId,
        uint256 initAmount,
        bytes10 accessKey,
        Duration _startTime_,
        Duration _stopTime_,
        uint8 _manager
*/
contract TestLobby is Test {
    Lobby internal lobby;

    function setUp() public {
        vm.startPrank(address(2));
        lobby = new Lobby();
        for (uint256 i; i < 8; ++i) {
            uint256 j = i + 100;
            lobby.AddManager(vm.addr(j));
        }
        vm.stopPrank();
    }

    function test_newAuction() public {
        hoax(address(1),100 ether);
        (bool ok, ) = address(lobby).call{value: 10 ether}(abi.encodeWithSelector(0x5b365040, ""));
        require(ok,"USDT purchase unsuccessful");
        bytes10 accessKey = bytes10(lobby.generateKey(1e16, 1738));
        nft memory _NFT = lobby.createNFT("Dodge", "DGE", 8);
        address auction = lobby.newAuction(msg.sender, "Dodge NFT", _NFT.nftAddress, 1, 2 ether, accessKey, Duration.Day, Duration.Week, 2);
        
        vm.assertEq(msg.sender, auction, "The address are not equal");
    }
}
