// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./utils/Counters.sol";
import "./token/ERC721/ERC721.sol";
import "./security/ReentrancyGuard.sol";
import "./utils/Strings.sol";

import "./INftRegistry.sol";

contract NftRegistry is ReentrancyGuard, INftRegistry {
	uint256 private constant VERSION = 20221111003;

	address private _nftRegistryOwner;

	// registry data
	using Counters for Counters.Counter;
	Counters.Counter private _nftsSold;
	Counters.Counter private _nftCount;


	mapping(uint256 => NFT) private _idToNFT; // entire list
	mapping(address => uint256[]) private _contractList; // entry by ER721 contract
	mapping(address => uint256[]) private _sellerList; // entry by seller


	// constructor
	constructor(address _owner) {
		_nftRegistryOwner = _owner;
	}

	function getVersion() public pure returns (uint256) {
		return VERSION;
	}

	function getVersionString() external view returns (string memory) {
		string memory ver = string.concat("nfr: ",Strings.toString(VERSION));

		return ver;
	}

	// nfts
	function getNftCount() public view returns (uint256) {
		return _nftCount.current();
	}


	function registerNft(address _nftContract, uint256 _tokenId, uint256 _price, address _token, uint256 _feeIndex, address _seller, address _owner, address _originator, bool _flag) public payable nonReentrant {
		// TODO: check if nft is already registered
		_nftCount.increment();

		uint nftIndex = _nftCount.current();

		uint256[] storage contractnftindexes =  _contractList[_nftContract];
		contractnftindexes.push(nftIndex);

		uint256[] storage sellernftindexes =  _sellerList[_seller];
		sellernftindexes.push(nftIndex);

		_idToNFT[nftIndex] = NFT(
		nftIndex,
		_nftContract,
		_tokenId, 
		_token,
		payable(_seller),
		payable(_owner),
		payable(_originator),
		_price,
		_feeIndex,
		_flag
		);
	}

	function modifyNftAt(uint256 _nftIndex, address _seller, address _owner, address _originator, uint256 _price, uint256 _feeIndex, bool _flag) public payable {
		NFT storage nft = _idToNFT[_nftIndex];

		if (nft.seller != _seller) nft.seller = payable(_seller);
		if (nft.owner != _owner) nft.owner = payable(_owner);
		if (nft.originator != _originator) nft.originator = payable(_originator);
		if (nft.price != _price) nft.price = _price;
		if (nft.feeIndex != _feeIndex) nft.feeIndex = _feeIndex;
		if (nft.listed != _flag) {
			nft.listed = _flag;

			if (_flag == true) {
				_nftsSold.decrement();
			}
			else {
				_nftsSold.increment();
			}
		}
	}


	function getAllNfts() public view returns (NFT[] memory) {
		uint256 nftCount = _nftCount.current();

		NFT[] memory nfts = new NFT[](nftCount);
		uint nftsIndex = 0;
		for (uint i = 0; i < nftCount; i++) {
			nfts[nftsIndex] = _idToNFT[i + 1];
			nftsIndex++;
		}
		return nfts;
	}

	function getAllNftsBetween(uint256 _start, uint256 _end) public view returns (NFT[] memory) {
		uint size = _end - _start;
		NFT[] memory nfts = new NFT[](size);
		uint nftsIndex = 0;
		for (uint i = 0; i < size; i++) {
			nfts[nftsIndex] = _idToNFT[_start + i + 1];
			nftsIndex++;
		}
		return nfts;
	}

	function getNft(address _nftContract, uint256 _tokenId) public view returns (NFT memory) {
		uint256[] storage contractnftindexes =  _contractList[_nftContract];

		uint256 size = contractnftindexes.length;
		for (uint256 i = 0; i < size; i++) {
		NFT memory nft = _idToNFT[contractnftindexes[i]];

		if (nft.tokenId == _tokenId)
			return nft;
		}

		revert('Not found');
	}

	function getNftAt(uint256 _nftIndex) public view returns (NFT memory) {
		return _idToNFT[_nftIndex];
	}

	function getListedNfts() public view returns (NFT[] memory) {
		uint256 nftCount = _nftCount.current();
		uint256 unsoldNftsCount = nftCount - _nftsSold.current();

		NFT[] memory nfts = new NFT[](unsoldNftsCount);
		uint nftsIndex = 0;
		for (uint i = 0; i < nftCount; i++) {
			if (_idToNFT[i + 1].listed) {
				nfts[nftsIndex] = _idToNFT[i + 1];
				nftsIndex++;
			}
		}
		return nfts;
	}

	function getListedNftsBetween(uint256 _start, uint256 _end) public view returns (NFT[] memory) {
		uint size = _end - _start;
		uint count = 0;

		for (uint i = 0; i < size; i++) {
			if (_idToNFT[_start + i + 1].listed) {
				count++;
			}
		}

		NFT[] memory nfts = new NFT[](count);
		uint nftsIndex = 0;

		for (uint i = 0; i < size; i++) {
			if (_idToNFT[_start + i + 1].listed) {
				nfts[nftsIndex] = _idToNFT[_start + i + 1];
				nftsIndex++;
			}
		}
		return nfts;
	}


	function getMyNfts(address _owner) public view returns (NFT[] memory) {
		require(msg.sender == _nftRegistryOwner, "can only be called from proxy contract");
		uint256[] storage sellernftindexes =  _sellerList[_owner];

		uint256 size = sellernftindexes.length;
		NFT[] memory nfts = new NFT[](size);
		uint nftsIndex = 0;

		for (uint256 i = 0; i < size; i++) {
			NFT memory nft = _idToNFT[sellernftindexes[i]];
			nfts[nftsIndex] =  nft;
			nftsIndex++;
		}
		return nfts;
	}

	function getMyListedNfts(address _owner) public view returns (NFT[] memory) {
		require(msg.sender == _nftRegistryOwner, "can only be called from proxy contract");
		uint256[] storage sellernftindexes =  _sellerList[_owner];
		uint256 size = sellernftindexes.length;
		uint count = 0;
		for (uint256 i = 0; i < size; i++) {
		NFT memory nft = _idToNFT[sellernftindexes[i]];
			if (nft.listed) {
				count++;
			}
		}
		NFT[] memory nfts = new NFT[](count);
		uint nftsIndex = 0;

		for (uint256 i = 0; i < size; i++) {
		NFT memory nft = _idToNFT[sellernftindexes[i]];
			if (nft.listed) {
				nfts[nftsIndex] =  nft;
				nftsIndex++;
			}
		}
		return nfts;
	}
}