// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// EXTERNAL IMPORTS
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

struct Agreement {
  // TODO: those fields have to be immutable
  address buyer;
  address seller;
  // the address of the NFT the seller is selling.
  address nftAddress;
  // the ID of the NFT.
  uint tokenID;
  // the address of the SuperToken the seller accepts as payment.
  address acceptedToken;
  // the total price that the buyer has to pay
  uint price;
  // the date at which the dept will be paid off in UNIX seconds.
  uint endDate;
  // the deposit the buyer has to lock in. Defined by the seller in wei.
  uint deposit;
}

contract Broke {
  ISuperfluid immutable internal host;
  IConstantFlowAgreementV1 immutable internal cfa;
  mapping(bytes32 => Agreement) private agreements;

  constructor(
    address _host,
    address _cfa
  ) {
    require(_host != address(0), "host address needs to be defined");
    require(_cfa != address(0), "cfa address neds to be defined");
    host = ISuperfluid(_host);
    cfa = IConstantFlowAgreementV1(_cfa);
  }

  function getAgreement(bytes32 id) external returns (Agreement memory) {
    return agreements[id];
  }

  /// @notice creates a new agreement which a buyer can accept.
  /// @dev verifies that the user actually owns the token they're trying to sell.
  /// @param _nftAddress the address of the NFT the seller is selling.
  /// @param _tokenID the token ID of the NFT.
  /// @param _superfluidTokenAddress the token which the seller accepts as payment.
  /// @param _price the total price for which they want to sell it.
  /// @param _length the total length in seconds of the agreement.
  /// @param _deposit the deposit the seller expects from the buyer in wei.
  /// @return the bytes32 hash identifier of the agreement.
  /// TODO: use correct token type
  function createAgreement(
    address _nftAddress,
    uint _tokenID,
    address _superfluidTokenAddress,
    uint _price,
    uint _length,
    uint _deposit
  ) external returns (bytes32) {
    require(_superfluidTokenAddress != address(0), "superfluidTokenAddress has to be defined");
    require(_nftAddress != address(0), "nft has to be defined");

    IERC721 nft = IERC721(_nftAddress);
    // we approve the retrieval here and actually transfer if a buyer signs the agreement.
    nft.approve(address(this), _tokenID);

    // TODO: use safe math here!
    uint _endDate = block.timestamp + _length;
    Agreement memory agreement = Agreement({
      buyer: address(0),
      seller: msg.sender,
      nftAddress: _nftAddress,
      tokenID: _tokenID,
      acceptedToken: _superfluidTokenAddress,
      price: _price,
      endDate: _endDate,
      deposit: _deposit
    });
    bytes32 agreementHash = keccak256(abi.encode(agreement));
    agreements[agreementHash] = agreement;
    return agreementHash;
  }

  /// @notice accepts an existing agreement and starts a stream
  /// from the buyer to the seller
  /// @dev verifies that the seller still owns the item
  /// @param id the ID of the agreement they want to accept
  function acceptAgreement(bytes32 id) external payable {
    Agreement memory agreement = agreements[id];
    IERC721 nft = IERC721(agreement.nftAddress);
    require(address(this) == nft.getApproved(agreement.tokenID), "seller removed approval. Contract can't lock up sellers NFT!");

    require(msg.value == agreement.deposit, "have to send the exact deposit with the transaction");

    agreement.buyer = msg.sender;
  }

  /// @notice Allows seller to retrieve the token if the buyer closed the stream to early
  /// or ran out of funds.
  /// Allows buyer to retrieve token if the debt was fully paid off. Also closes the stream
  /// automatically after the buyer retrieved the token.
  /// @param id the ID of the agreement
  function retrieveToken(bytes32 id) external {
    // we could use a modifier to only allow the buyer and seller to call the function.
    // But, then we would have to still sepearte between seller and buyer
    // since both take a different path. Thus, using a modifier is gas waste here.
    Agreement memory agreement = agreements[id];
    if (msg.sender == agreement.seller) {

    } else if (msg.sender == agreement.buyer) {

      // should automatically close the stream
    } else {
      revert("Caller has to be either buyer or seller");
    }
  }

  /// @notice Allows the buyer to close the stream. Doesn't matter if the debt was paid off
  /// fully or not.
  function closeStream(bytes32 id) public {
    Agreement memory agreement = agreements[id];
    require(msg.sender == agreement.buyer, "only buyer can close the stream");
  }
}
