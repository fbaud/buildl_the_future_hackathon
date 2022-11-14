// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

enum FeeType { FLAT, PERCENT}

struct Fee {
	uint256 feeIndex;
	string name;
	FeeType feetype;
	uint256 originatorfee;
	uint256 marketplacefee;
	uint256 distributorfee;
	uint256 networkfee;
	bool active;
}