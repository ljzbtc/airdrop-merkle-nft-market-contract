// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Token is ERC721 {

    address public owner;

    
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        owner = msg.sender;
    }

    function mint(address to, uint256 tokenId) public {

        require(msg.sender == owner, "ERC721: mint to the zero address");

        _mint(to, tokenId);
    }
    function changeOwner(address newOwner) public {
        require(msg.sender == owner, "ERC721: mint to the zero address");
        owner = newOwner;
    }
}