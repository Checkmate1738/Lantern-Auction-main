//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721, Ownable {
    uint256 internal tokenId;
    string internal url;

    event NewNFT(address indexed to, uint256 id);

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender){
        for (uint256 i; i < 10; i++) {
            _safeMint(msg.sender, tokenId);
            tokenId++;
        }
    }

    function mint() payable external {
        uint256 tokenId_ = tokenId;
        tokenId++; // Increment the token ID counter
        _safeMint(msg.sender, tokenId_);
        emit NewNFT(msg.sender, tokenId_);
    }

    function _baseURI() internal view override returns(string memory) {
        return url;
    } 

    function setUrl(string memory path) external onlyOwner {
        url = path;
        _baseURI();
    }
}