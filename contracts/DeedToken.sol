// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC721 } from "./token/ERC721/ERC721.sol";
import "./access/Ownable.sol";
import "./utils/Counters.sol";

contract DeedToken is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    // Constructor will be called on contract creation
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    // Allows minting of a new NFT 
    function mint(address to) public onlyOwner() {
        _mint(to, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }
}