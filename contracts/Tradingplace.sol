// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./utils/Counters.sol";
import "./token/ERC721/ERC721.sol";
import "./security/ReentrancyGuard.sol";
import "./utils/Strings.sol";


import "./token/ERC20/extensions/IERC20Metadata.sol";
import "./token/ERC20/IERC20.sol";

import "./Fee.sol";
import "./IFeeRegistry.sol";
import "./INftRegistry.sol";
import "./ITradingplace.sol";
import "./IMarketplace.sol";

contract Tradingplace is ReentrancyGuard, ITradingplace {
	uint256 private constant VERSION = 20221111004;

	address private _nftRegistry;
	address private _feeRegistry;

	address payable private _tradingOwner;
	address payable private _networkAccount;

	// events
	event NFTListed(
		address nftContract,
		uint256 tokenId,
		address seller,
		address originator,
		uint256 price,
		address token
	);
	event NFTDelisted(
		address nftContract,
		uint256 tokenId,
		address seller,
		address originator,
		uint256 price,
		address token
	);
	event NFTSold(
		address nftContract,
		uint256 tokenId,
		address seller,
		address buyer,
		address distributor,
		uint256 price,
		address token
	);

	constructor(address _owner, address feeregistry, address nftregistry) {
		_tradingOwner = payable(_owner);
		_feeRegistry = feeregistry;
		_nftRegistry = nftregistry;
	}

	function getVersion() public pure returns (uint256) {
		return VERSION;
	}

	function getVersionString() external view returns (string memory) {
		string memory ver = string.concat("trd: ",Strings.toString(VERSION));

		return ver;
	}

	function getTradingOwner() public view  returns (address) {
		return _tradingOwner;
	}
	
	function getNetworkAccount() override public view returns (address) {
		return _networkAccount ;
	}
	
	function setNetworkAccount(address _account) override public payable nonReentrant {
		require(msg.sender == _tradingOwner);
		_networkAccount = payable(_account);
	}
	

	// List the NFT on the marketplace
	function listNft(address _nftContract, uint256 _tokenId, uint256 _price, address _token, uint256 _feeIndex, address _seller, address _originator) public payable nonReentrant {
		require(_price > 0, "Price must be at least 1 wei");

		// TODO: check if nft is already registered

		IMarketplace(_tradingOwner).transferNft(_nftContract, _seller, _tradingOwner, _tokenId);

		INftRegistry(_nftRegistry).registerNft(_nftContract, _tokenId, _price, _token, _feeIndex, _seller, _tradingOwner, _originator, true);

		emit NFTListed(_nftContract, _tokenId, _seller, _originator, _price, _token);
	}

	// de-list an NFT
	function delistNft(uint256 _nftIndex, address _seller, address _originator) public payable nonReentrant {
		NFT memory nft = INftRegistry(_nftRegistry).getNftAt(_nftIndex);

		require(msg.sender == nft.seller, "Not the seller, can not delist");

		IMarketplace(_tradingOwner).transferNft(nft.nftContract, _tradingOwner, _seller, nft.tokenId);

		INftRegistry(_nftRegistry).modifyNftAt(_nftIndex, nft.seller, nft.owner, _originator, nft.price, nft.feeIndex, false);

		emit NFTDelisted(nft.nftContract, nft.tokenId, _seller, _originator, nft.price, nft.token);
	}

	function _getTokenFeeSplit(NFT memory nft, Fee memory fee) private pure returns (uint256[4] memory) {
		uint256[4] memory fees;

		if (fee.feetype == FeeType.FLAT) {
			fees[0] = fee.originatorfee;
			fees[1] = fee.marketplacefee;
			fees[2] = fee.distributorfee;
			fees[3] = fee.networkfee;
		}
		else if (fee.feetype == FeeType.PERCENT) {
			fees[0] = fee.originatorfee * nft.price / 10000;
			fees[1] = fee.marketplacefee * nft.price / 10000;
			fees[2] = fee.distributorfee * nft.price / 10000;
			fees[3] = fee.networkfee * nft.price / 10000;
		}
		else {
			require(false, "fee type is not correct");
		}

		return fees;
	}

	function getNftFullPrice(uint256 _nftIndex) public view returns (uint256){
		NFT memory nft = INftRegistry(_nftRegistry).getNftAt(_nftIndex);
		Fee[] memory fees = IFeeRegistry(_feeRegistry).getTokenFees(nft.token);

		require(fees.length > 0, "The token has not been registered");

		Fee memory fee = fees[nft.feeIndex];

		uint256[4] memory fullfees = _getTokenFeeSplit(nft, fee);
		uint256 originatorfee = fullfees[0];
		uint256 marketplacefee = fullfees[1];
		uint256 distributorfee = fullfees[2];
		uint256 networkfee = fullfees[3];

		uint256 fullprice = nft.price + originatorfee + marketplacefee + distributorfee + (_networkAccount != address(0) ? networkfee : 0);

		return fullprice;
	}

	
	// Buy an NFT
	function buyNft(uint256 _nftIndex, address _buyer, address _distributor) public payable nonReentrant {
		NFT memory nft = INftRegistry(_nftRegistry).getNftAt(_nftIndex);
		Fee[] memory fees = IFeeRegistry(_feeRegistry).getTokenFees(nft.token);

		require(fees.length > 0, "The token has not been registered");

		Fee memory fee = fees[nft.feeIndex];
		// require(msg.value >= nft.price, "Not enough ether to cover asking price");

		uint256[4] memory fullfees = _getTokenFeeSplit(nft, fee);

		IMarketplace(_tradingOwner).transferTokenAmount(nft.token, _buyer, nft.seller, nft.price);

		if (fullfees[0] > 0)
		IMarketplace(_tradingOwner).transferTokenAmount(nft.token, _buyer, nft.originator, fullfees[0]);

		if (fullfees[1] > 0)
		IMarketplace(_tradingOwner).transferTokenAmount(nft.token, _buyer, _tradingOwner, fullfees[1]);

		if (fullfees[2] > 0)
		IMarketplace(_tradingOwner).transferTokenAmount(nft.token, _buyer, _distributor, fullfees[2]);

		if ( (fullfees[3] > 0) && (_networkAccount != address(0)))
		IMarketplace(_tradingOwner).transferTokenAmount(nft.token, _buyer, _networkAccount, fullfees[3]);

		IMarketplace(_tradingOwner).transferNft(nft.nftContract, _tradingOwner, _buyer, nft.tokenId);

		INftRegistry(_nftRegistry).modifyNftAt(_nftIndex, nft.seller, _buyer, nft.originator, nft.price, nft.feeIndex, false);
		
		emit NFTSold(nft.nftContract, nft.tokenId, nft.seller, _buyer, _distributor, nft.price, nft.token);
	}

	// Resell an NFT purchased from the marketplace
	function resellNft(uint256 _nftIndex, uint256 _price, address _seller, address _originator) public payable nonReentrant {
		require(_price > 0, "Price must be at least 1 wei");

		NFT memory nft = INftRegistry(_nftRegistry).getNftAt(_nftIndex);

		IMarketplace(_tradingOwner).transferNft(nft.nftContract, _seller, _tradingOwner, nft.tokenId);

		INftRegistry(_nftRegistry).modifyNftAt(_nftIndex, _seller, _tradingOwner, _originator, _price, nft.feeIndex, true);

		emit NFTListed(nft.nftContract, nft.tokenId, _seller, _tradingOwner, _price, nft.token);
	}
}