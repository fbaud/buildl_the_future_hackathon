// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ITradingplace {
	function getVersion() external pure returns (uint256);
	function getVersionString() external view returns (string memory);

	function getNetworkAccount() external view returns (address);
	function setNetworkAccount(address _account) external payable;

	function listNft(address _nftContract, uint256 _tokenId, uint256 _price, address _token, uint256 _feeIndex, address _seller, address _originator) external payable;
	function delistNft(uint256 _nftIndex, address _seller, address _originator) external payable;
	function getNftFullPrice(uint256 _nftIndex) external view returns (uint256);
	function buyNft(uint256 _nftIndex, address _buyer, address _distributor) external payable;
	function resellNft(uint256 _nftIndex, uint256 _price, address _seller, address _originator) external payable;
}