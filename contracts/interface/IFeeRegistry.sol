// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../market/Fee.sol";

interface IFeeRegistry {
	function getVersion() external pure returns (uint256);
	function getVersionString() external view returns (string memory);

	function registerToken(address _token) external payable;

	function createFee(string memory _name, address _token, FeeType _feetype, 
                      uint256 _originatorfee, uint256 _marketplacefee, uint256 _distributorfee, uint256 _networkfee) external payable;
	function getAllFees() external view returns (Fee[] memory);
	function getTokenFees(address _token) external view returns (Fee[] memory) ;
}