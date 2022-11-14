// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct NFT {
	uint256 nftIndex;
	address nftContract;
	uint256 tokenId;
	address token;
	address payable seller;
	address payable owner;
	address payable originator;
	uint256 price;
	uint256 feeIndex;
	bool listed;
}
