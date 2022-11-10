// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./token/ERC721/ERC721.sol";

import "./token/ERC20/extensions/IERC20Metadata.sol";
import "./token/ERC20/IERC20.sol";

import "./security/ReentrancyGuard.sol";
import "./utils/Strings.sol";

import "./FeeRegistry.sol";
import "./NftRegistry.sol";
import "./Tradingplace.sol";

import "./IMarketplace.sol";

contract Marketplace is ReentrancyGuard, IMarketplace {
	uint256 private constant VERSION = 20221111001;

	address private _feeRegistry;
	address private _nftRegistry;
	address private _tradingPlace;

	address payable private _marketOwner;

	constructor() {
		_marketOwner = payable(msg.sender);
	}

	// called by owner
	function setFeeRegistry(address _contract) override public payable nonReentrant {
		require(msg.sender == _marketOwner);
		_feeRegistry = _contract;
	}

	function setNftRegistry(address _contract) override public payable nonReentrant {
		require(msg.sender == _marketOwner);
		_nftRegistry = _contract;
	}

	function setTradingplace(address _contract) override public payable nonReentrant {
		require(msg.sender == _marketOwner);
		_tradingPlace = _contract;
	}

	function setNetworkAccount(address _account) override public payable nonReentrant {
		require(msg.sender == _marketOwner);
		ITradingplace(_tradingPlace).setNetworkAccount(_account);
	}

	function getNetworkAccount() override public view  returns (address) {
		return ITradingplace(_tradingPlace).getNetworkAccount();
	}

	// called by trading place
	function transferTokenAmount(address _token, address _from, address _to, uint256 _amount) override public payable {
		require(msg.sender == address(_tradingPlace), "only trading place contract can call this method");
		IERC20(_token).transferFrom(_from, _to, _amount);
	}

	function transferNft(address _nftContract, address _from, address _to, uint256 _tokenId) override public payable { 
		require(msg.sender == address(_tradingPlace), "only trading place contract can call this method");
		IERC721(_nftContract).transferFrom(_from, _to, _tokenId);
	}

	// create Fee
	function registerToken(address _token) override public payable {
		IFeeRegistry(_feeRegistry).registerToken(_token);
	}

	function createFee(string memory _name, address _token, FeeType _feetype, 
						uint256 _originatorfee, uint256 _marketplacefee, uint256 _distributorfee, uint256 _networkfee) override public payable {
		IFeeRegistry(_feeRegistry).createFee(_name, _token, _feetype, _originatorfee, _marketplacefee, _distributorfee, _networkfee);
	}


	// List the NFT on the marketplace
	function registerNft(address _nftContract, uint256 _tokenId, uint256 _price, address _token, uint256 _feeIndex, address _seller, address _owner, address _originator, bool _flag) public payable nonReentrant {
		NftRegistry(_nftRegistry).registerNft(_nftContract, _tokenId, _price, _token, _feeIndex, _seller, _owner, _originator, _flag);
	}

	function modifyNftAt(uint256 _nftIndex, address _seller, address _owner, address _originator, uint256 _price, uint256 _feeIndex, bool _flag) public payable {
		NftRegistry(_nftRegistry).modifyNftAt(_nftIndex, _seller, _owner, _originator, _price, _feeIndex, _flag);
	}

	function listNft(address _nftContract, uint256 _tokenId, uint256 _price, address _token, uint256 _feeIndex, address _originator) public payable nonReentrant {
		ITradingplace(_tradingPlace).listNft(_nftContract, _tokenId, _price, _token, _feeIndex, msg.sender, _originator);
	}

	// de-list an NFT
	function delistNft(uint256 _nftIndex, address _originator) public payable nonReentrant {
		ITradingplace(_tradingPlace).delistNft( _nftIndex, msg.sender, _originator);
	}

	
	// Buy an NFT
	function buyNft(uint256 _nftIndex, address _distributor) public payable nonReentrant {
		ITradingplace(_tradingPlace).buyNft(_nftIndex, msg.sender, _distributor);
	}

	// Resell an NFT purchased from the marketplace
	function resellNft(uint256 _nftIndex, uint256 _price, address _originator) public payable nonReentrant {
		ITradingplace(_tradingPlace).resellNft( _nftIndex, _price, msg.sender, _originator);
	}


	// read functions
	function getVersion() public pure returns (uint256) {
		return VERSION;
	}

	function getVersionString() external view returns (string memory) {
		string memory ver = string.concat("mkt: ",Strings.toString(VERSION));

		ver = string.concat(ver, " - ");
		ver = string.concat(ver, IFeeRegistry(_feeRegistry).getVersionString());

		ver = string.concat(ver, " - ");
		ver = string.concat(ver, NftRegistry(_nftRegistry).getVersionString());

		ver = string.concat(ver, " - ");
		ver = string.concat(ver, ITradingplace(_tradingPlace).getVersionString());

		return ver;
	}


	function getNftCount() public view returns (uint256) {
		return NftRegistry(_nftRegistry).getNftCount();
	}

	// fees
	function getAllFees() override public view returns (Fee[] memory) {
		return IFeeRegistry(_feeRegistry).getAllFees();
	}

	function getTokenFees(address _token) override public view returns (Fee[] memory) {
		return IFeeRegistry(_feeRegistry).getTokenFees(_token);
	}


	// nfts
	function getAllNfts() public view returns (NFT[] memory) {
		return NftRegistry(_nftRegistry).getAllNfts();
	}

	function getAllNftsBetween(uint256 _start, uint256 _end) public view returns (NFT[] memory) {
		return NftRegistry(_nftRegistry).getAllNftsBetween(_start, _end);
	}

	function getNft(address _nftContract, uint256 _tokenId) public view returns (NFT memory) {
		return NftRegistry(_nftRegistry).getNft(_nftContract, _tokenId);
	}

	function getNftFullPrice(uint256 _nftIndex) public view returns (uint256){
		return ITradingplace(_tradingPlace).getNftFullPrice(_nftIndex);
	}

	function getNftAt(uint256 _nftIndex) public view returns (NFT memory) {
		return NftRegistry(_nftRegistry).getNftAt(_nftIndex);
	}

	function getListedNfts() public view returns (NFT[] memory) {
		return NftRegistry(_nftRegistry).getListedNfts();
	}

	function getListedNftsBetween(uint256 _start, uint256 _end) public view returns (NFT[] memory) {
		return NftRegistry(_nftRegistry).getListedNftsBetween(_start, _end);
	}


	function getMyNfts(address _owner) public view returns (NFT[] memory) {
		require(_owner == msg.sender, "must provide your own address");
		return NftRegistry(_nftRegistry).getMyNfts(msg.sender);
	}

	function getMyListedNfts(address _owner) public view returns (NFT[] memory) {
		require(_owner == msg.sender, "must provide your own address");
		return NftRegistry(_nftRegistry).getMyListedNfts(msg.sender);
	}
}