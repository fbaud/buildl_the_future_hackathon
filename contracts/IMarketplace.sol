// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


import "./INftRegistry.sol";
import "./IFeeRegistry.sol";

interface IMarketplace is IFeeRegistry, INftRegistry {
	function getVersion() external pure override(IFeeRegistry, INftRegistry) returns (uint256);
	function getVersionString() external view override(IFeeRegistry, INftRegistry) returns (string memory);
	function setFeeRegistry(address _contract) external payable;
	function setNftRegistry(address _contract) external payable;
	function setTradingplace(address _contract) external payable;

	function getNetworkAccount() external view returns (address);
	function setNetworkAccount(address _account) external payable;

	function listNft(address _nftContract, uint256 _tokenId, uint256 _price, address _token, uint256 _feeIndex, address _originator) external payable;
	function delistNft(uint256 _nftIndex, address _originator) external payable;
	function getNftFullPrice(uint256 _nftIndex) external view returns (uint256);
	function buyNft(uint256 _nftIndex, address _distributor) external payable;
	function resellNft(uint256 _nftIndex, uint256 _price, address _originator) external payable;

	function transferTokenAmount(address _token, address _from, address _to, uint256 _amount) external payable;
	function transferNft(address _nftContract, address _from, address _to, uint256 _tokenId) external payable;
}