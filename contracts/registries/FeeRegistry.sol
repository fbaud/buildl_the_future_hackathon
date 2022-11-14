// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../market/Fee.sol";

import "../interface/IFeeRegistry.sol";

contract FeeRegistry  is IFeeRegistry, ReentrancyGuard {
	uint256 private constant VERSION = 20221111002;

	address private _feeregistryOwner;

	// registry data
	using Counters for Counters.Counter;

	Fee private DEFAULT_FEE = Fee(0, "default", FeeType.PERCENT, 125, 50, 125, 0, true);

	Counters.Counter private _tokenCount;
	mapping(uint256 => address) private _tokens;

	mapping(address => Fee[]) private _tokenToFees;

	// event
	event FeeCreated(
		uint256 feeIndex,
		string name,
		address token,
		FeeType feetype,
		uint256 originatorfee,
		uint256 marketplacefee,
		uint256 distributorfee,
		uint256 networkfee
	);

	// constructor
	constructor(address _owner) {
		_feeregistryOwner = _owner;
	}

	function getVersion() public pure returns (uint256) {
		return VERSION;
	}

	function getVersionString() external view returns (string memory) {
		string memory ver = string.concat("fer: ",Strings.toString(VERSION));

		return ver;
	}


	// create Fee
	function registerToken(address _token) virtual public payable nonReentrant {
		require(msg.sender == _feeregistryOwner);

		Fee[] storage fees = _tokenToFees[_token];

		uint feeIndex = fees.length;

		if (feeIndex == 0) {
			// sets default fee

			// set token in token mapping
			_tokenCount.increment();

			uint256 _tokenIndex = _tokenCount.current();

			_tokens[_tokenIndex] = _token;

			// insert default fee
			fees.push(DEFAULT_FEE);
		}
	}

	function createFee(string memory _name, address _token, FeeType _feetype, 
						uint256 _originatorfee, uint256 _marketplacefee, uint256 _distributorfee, uint256 _networkfee) virtual public payable nonReentrant {
		require(msg.sender == _feeregistryOwner);

		Fee[] storage fees = _tokenToFees[_token];

		uint feeIndex = fees.length;

		require(feeIndex > 0, "token is not registered in the marketplace");

		// insert new fee
		Fee memory fee = Fee(feeIndex, _name, _feetype, _originatorfee, _marketplacefee, _distributorfee, _networkfee, true);

		fees.push(fee);

		emit FeeCreated(feeIndex, _name, _token, _feetype, _originatorfee, _marketplacefee, _distributorfee, _networkfee);
	}

	function getAllFees() virtual public view returns (Fee[] memory) {
		uint256 tokenCount = _tokenCount.current();

		uint arr_size = 0;
		for (uint i = 0; i < tokenCount; i++) {
			address token = _tokens[i+1];
			Fee[] storage tokenfees = _tokenToFees[token];

			arr_size += tokenfees.length;
		}

		Fee[] memory allfees = new Fee[](arr_size);
		uint feesIndex = 0;

		for (uint i = 0; i < tokenCount; i++) {
			address token = _tokens[i+1];
			Fee[] storage tokenfees = _tokenToFees[token];
			
			for (uint j = 0; j < tokenfees.length; j++) {
			allfees[feesIndex] = tokenfees[j];
			feesIndex++;
			}
		}

		return allfees;
	}
	
	function getTokenFees(address _token) virtual public view returns (Fee[] memory) {
		return _tokenToFees[_token];
	}
	

}