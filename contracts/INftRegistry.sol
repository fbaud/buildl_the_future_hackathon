// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./NFT.sol";

interface INftRegistry {
	function getVersion() external pure returns (uint256);
	function getVersionString() external view returns (string memory);

	function getNftCount() external view returns (uint256);

	function registerNft(address _nftContract, uint256 _tokenId, uint256 _price, address _token, uint256 _feeIndex, address _seller, address _owner, address _originator, bool _flag) external payable;
	function modifyNftAt(uint256 _nftIndex, address _seller, address _owner, address _originator, uint256 _price, uint256 _feeIndex, bool _flag) external payable;

	function getAllNftsBetween(uint256 _start, uint256 _end) external view returns (NFT[] memory);
	function getNft(address _nftContract, uint256 _tokenId) external view returns (NFT memory);
	function getNftAt(uint256 _nftIndex) external view returns (NFT memory);
	function getListedNfts() external view returns (NFT[] memory);
	function getListedNftsBetween(uint256 _start, uint256 _end) external view returns (NFT[] memory);
	function getMyNfts(address _owner) external view returns (NFT[] memory);
	function getMyListedNfts(address _owner) external view returns (NFT[] memory);
}