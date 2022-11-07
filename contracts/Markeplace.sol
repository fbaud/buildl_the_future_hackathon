// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./utils/Counters.sol";
import "./token/ERC721/ERC721.sol";
import "./security/ReentrancyGuard.sol";


import "./token/ERC20/extensions/IERC20Metadata.sol";
import "./token/ERC20/IERC20.sol";


contract Marketplace is ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private _nftsSold;
  Counters.Counter private _nftCount;

  uint256 public constant VERSION = 20221103001;
  uint256 public LISTING_FEE = 0.0001 ether;

  Fee private DEFAULT_FEE = Fee(0, "default", FeeType.PERCENT, 25, 10, 25, 0, true);

  address payable private _marketOwner;
  address payable private _networkAccount;

  enum FeeType { FLAT, PERCENT}

  Counters.Counter private _tokenCount;
  mapping(uint256 => address) private _tokens;

  mapping(address => Fee[]) private _tokenToFees;
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

  mapping(uint256 => NFT) private _idToNFT;
  struct NFT {
    uint256 nftIndex;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    address payable originator;
    address token;
    uint256 price;
    uint256 feeIndex;
    bool listed;
  }

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

  constructor() {
    _marketOwner = payable(msg.sender);
  }

  // create Fee
  function registerToken(address _token) public payable nonReentrant {
    require(msg.sender == _marketOwner);

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
                      uint256 _originatorfee, uint256 _marketplacefee, uint256 _distributorfee, uint256 _networkfee) public payable nonReentrant {
    require(msg.sender == _marketOwner);

    Fee[] storage fees = _tokenToFees[_token];

    uint feeIndex = fees.length;

    require(feeIndex > 0, "token is not registered in the marketplace");

    // insert new fee
    Fee memory fee = Fee(feeIndex, _name, _feetype, _originatorfee, _marketplacefee, _distributorfee, _networkfee, true);

    fees.push(fee);

    emit FeeCreated(feeIndex, _name, _token, _feetype, _originatorfee, _marketplacefee, _distributorfee, _networkfee);
  }


  // List the NFT on the marketplace
  function listNft(address _nftContract, uint256 _tokenId, uint256 _price, address _token, uint256 _feeIndex, address _originator) public payable nonReentrant {
    require(_price > 0, "Price must be at least 1 wei");
    require(msg.value == LISTING_FEE, "Not enough ether for listing fee");

    IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);

    // TODO: check if nft is already registered

    _nftCount.increment();

    uint nftIndex = _nftCount.current();

    _idToNFT[nftIndex] = NFT(
      nftIndex,
      _nftContract,
      _tokenId, 
      payable(msg.sender),
      payable(address(this)),
      payable(_originator),
      _token,
      _price,
      _feeIndex,
      true
    );

    emit NFTListed(_nftContract, _tokenId, msg.sender, _originator, _price, _token);
  }

   // de-list an NFT
  function delistNft(uint256 _nftIndex, address _originator) public payable nonReentrant {
    NFT storage nft = _idToNFT[_nftIndex];

    require(msg.sender == nft.seller, "Not the seller, can not delist");

    IERC721(nft.nftContract).transferFrom(address(this), msg.sender, nft.tokenId);

    nft.listed = false;

    _nftsSold.increment();
    emit NFTDelisted(nft.nftContract, nft.tokenId, msg.sender, _originator, nft.price, nft.token);
  }

 
  // Buy an NFT
  function buyNft(uint256 _nftIndex, address _distributor) public payable nonReentrant {
    NFT storage nft = _idToNFT[_nftIndex];
    Fee[] storage fees = _tokenToFees[nft.token];

    require(fees.length > 0, "The token has not been registered");

    Fee storage fee = fees[nft.feeIndex];
    // require(msg.value >= nft.price, "Not enough ether to cover asking price");

    uint256[4] memory fullfees = _getTokenFeeSplit(nft, fee);

    address payable buyer = payable(msg.sender);

    //payable(nft.seller).transfer(msg.value);
    //IERC721(_nftContract).transferFrom(address(this), buyer, nft.tokenId);

    IERC20 _ccytok = IERC20(nft.token);
    _ccytok.transferFrom(buyer, nft.seller, nft.price);

    if (fullfees[0] > 0)
    _ccytok.transferFrom(buyer, nft.originator, fullfees[0]);

    if (fullfees[1] > 0)
    _ccytok.transferFrom(buyer, _marketOwner, fullfees[1]);

    if (fullfees[2] > 0)
    _ccytok.transferFrom(buyer, _distributor, fullfees[2]);

    if ( (fullfees[3] > 0) && (_networkAccount != address(0)))
    _ccytok.transferFrom(buyer, _networkAccount, fullfees[3]);

    IERC721(nft.nftContract).transferFrom(address(this), buyer, nft.tokenId);

    _marketOwner.transfer(LISTING_FEE);
    nft.owner = buyer;
    nft.listed = false;

    _nftsSold.increment();
    emit NFTSold(nft.nftContract, nft.tokenId, nft.seller, buyer, _distributor, nft.price, nft.token);
  }

  // Resell an NFT purchased from the marketplace
  function resellNft(uint256 _nftIndex, uint256 _price, address _originator) public payable nonReentrant {
    require(_price > 0, "Price must be at least 1 wei");
    require(msg.value == LISTING_FEE, "Not enough ether for listing fee");

    NFT storage nft = _idToNFT[_nftIndex];

    IERC721(nft.nftContract).transferFrom(msg.sender, address(this), nft.tokenId);

    nft.seller = payable(msg.sender);
    nft.owner = payable(address(this));
    nft.originator = payable(_originator);
    nft.listed = true;
    nft.price = _price;

    _nftsSold.decrement();
    emit NFTListed(nft.nftContract, nft.tokenId, msg.sender, _originator, _price, nft.token);
  }


  // read functions
  function getListingFee() public view returns (uint256) {
    return LISTING_FEE;
  }

  function getVersion() public pure returns (uint256) {
    return VERSION;
  }

   // fees
  function getAllFees() public view returns (Fee[] memory) {
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

  function getTokenFees(address _token) public view returns (Fee[] memory) {
    Fee[] storage fees = _tokenToFees[_token];
    return fees;
  }

  function _getTokenFeeSplit(NFT storage nft, Fee storage fee) private view returns (uint256[4] memory) {
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

  // nfts
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

  function getNft(address _nftContract, uint256 _tokenId) public view returns (NFT memory) {
    uint256 nftCount = _nftCount.current();
    for (uint256 i = 0; i < nftCount; i++) {
      NFT memory nft = _idToNFT[i + 1];

      if ((nft.nftContract == _nftContract) && (nft.tokenId == _tokenId))
        return nft;
    }

    revert('Not found');
  }

  function getNftFullPrice(uint256 _nftIndex) public view returns (uint256){
    NFT storage nft = _idToNFT[_nftIndex];
    Fee[] storage fees = _tokenToFees[nft.token];

    require(fees.length > 0, "The token has not been registered");

    Fee storage fee = fees[nft.feeIndex];

    uint256[4] memory fullfees = _getTokenFeeSplit(nft, fee);
    uint256 originatorfee = fullfees[0];
    uint256 marketplacefee = fullfees[1];
    uint256 distributorfee = fullfees[2];
    uint256 networkfee = fullfees[3];

    uint256 fullprice = nft.price + originatorfee + marketplacefee + distributorfee + (_networkAccount != address(0) ? networkfee : 0);

    return fullprice;
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

  function getMyNfts() public view returns (NFT[] memory) {
    uint nftCount = _nftCount.current();
    uint myNftCount = 0;
    for (uint i = 0; i < nftCount; i++) {
      if (_idToNFT[i + 1].owner == msg.sender) {
        myNftCount++;
      }
    }

    NFT[] memory nfts = new NFT[](myNftCount);
    uint nftsIndex = 0;
    for (uint i = 0; i < nftCount; i++) {
      if (_idToNFT[i + 1].owner == msg.sender) {
        nfts[nftsIndex] = _idToNFT[i + 1];
        nftsIndex++;
      }
    }
    return nfts;
  }

  function getMyListedNfts() public view returns (NFT[] memory) {
    uint nftCount = _nftCount.current();
    uint myListedNftCount = 0;
    for (uint i = 0; i < nftCount; i++) {
      if (_idToNFT[i + 1].seller == msg.sender && _idToNFT[i + 1].listed) {
        myListedNftCount++;
      }
    }

    NFT[] memory nfts = new NFT[](myListedNftCount);
    uint nftsIndex = 0;
    for (uint i = 0; i < nftCount; i++) {
      if (_idToNFT[i + 1].seller == msg.sender && _idToNFT[i + 1].listed) {
        nfts[nftsIndex] = _idToNFT[i + 1];
        nftsIndex++;
      }
    }
    return nfts;
  }
}