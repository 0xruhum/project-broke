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
  uint256 tokenID;
  // the address of the SuperToken the seller accepts as payment.
  address acceptedToken;
  // the total price that the buyer has to pay.
  // in uint96 because Suoerfluid uses int96 for the flowrate.
  // Makes the conversion easier.
  uint96 price;
  // the length of the agreement in UNIX seconds.
  // in uint96 because Suoerfluid uses int96 for the flowrate.
  // Makes the conversion easier.
  uint96 length;
  // the deposit the buyer has to lock in. Defined by the seller in wei.
  uint256 deposit;
  // timestamp in UNIX at which the token is fully paid off by the buyer.
  uint256 endDate;
  // timestamp in UNIX of the creation by the seller.
  uint256 createdAt;
}

contract Broke {
  ISuperfluid internal immutable host;
  IConstantFlowAgreementV1 internal immutable cfa;
  // key: hash of sender + receiver
  mapping(bytes32 => Agreement) private agreements;

  constructor(address _host, address _cfa) {
    require(_host != address(0), "host address needs to be defined");
    require(_cfa != address(0), "cfa address needs to be defined");
    host = ISuperfluid(_host);
    cfa = IConstantFlowAgreementV1(_cfa);
    uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL |
      SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
      SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
      SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;
    ISuperfluid(_host).registerApp(configWord);
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
    uint256 _tokenID,
    address _superfluidTokenAddress,
    uint96 _price,
    uint96 _length,
    uint256 _deposit
  ) external returns (bytes32) {
    require(
      _superfluidTokenAddress != address(0),
      "superfluidTokenAddress has to be defined"
    );
    require(_nftAddress != address(0), "nft has to be defined");
    IERC721 nft = IERC721(_nftAddress);
    require(
      address(this) == nft.getApproved(_tokenID),
      "seller didn't approve contract to transfer the token"
    );

    Agreement memory agreement = Agreement({
      buyer: address(0),
      seller: msg.sender,
      nftAddress: _nftAddress,
      tokenID: _tokenID,
      acceptedToken: _superfluidTokenAddress,
      price: _price,
      length: _length,
      deposit: _deposit,
      createdAt: block.timestamp,
      endDate: 0
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
    require(
      isAgreementAcceptable(id),
      "The agreement is not available anymore"
    );
    Agreement storage agreement = agreements[id];
    // The Superfluid stream ID is the hash of the sender and the receiver
    bytes32 streamID = keccak256(abi.encode(msg.sender, agreement.seller));
    // verify that the buyer has started a stream with the correct flow data
    (
      uint256 ts,
      int96 flowRate,
      uint256 deposit,
      uint256 owedDeposit
    ) = getFlow(agreement.acceptedToken, msg.sender, agreement.seller);
    int96 agreementFlowRate = int96(agreement.price / agreement.length);
    require(agreementFlowRate == flowRate, "flow rate doesn't match");
    require(
      msg.value == agreement.deposit,
      "have to send the exact deposit with the transaction"
    );

    agreement.buyer = msg.sender;
    // we use the flow ts since that is the time at which the flow was started
    // and thus the endDate should be that + length.
    // Using block.timestamp wouldn't work since the stream is started
    // before the agreement is accepted. Thus, the buyer would overpay.
    agreement.endDate = ts + agreement.length;
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
    if (msg.sender == agreement.seller) {} else if (
      msg.sender == agreement.buyer
    ) {
      // should automatically close the stream
    } else {
      revert("Caller has to be either buyer or seller");
    }
  }

  /// @dev An agreement is acceptable if there is no buyer set and the
  /// contract is approved to transfer the NFT from the seller.
  /// @param id the ID of the agreement
  /// @return bool
  function isAgreementAcceptable(bytes32 id) public view returns (bool) {
    Agreement memory agreement = agreements[id];
    IERC721 nft = IERC721(agreement.nftAddress);
    if (
      agreement.buyer != address(0) ||
      nft.getApproved(agreement.tokenID) != address(this)
    ) {
      return false;
    }
    return true;
  }

  /// @dev pass the agreement instead of the ID
  /// so we don't have to read from storage again.
  /// @param token the supertoken the agreement uses
  /// @param buyer address of the buyer
  /// @param seller address of the seller
  /// @return (uint256, int96, uint256, uint256) the flow data
  function getFlow(
    address token,
    address buyer,
    address seller
  )
    public
    view
    returns (
      uint256,
      int96,
      uint256,
      uint256
    )
  {
    return cfa.getFlow(ISuperfluidToken(token), buyer, seller);
  }

  function hasCorrectAgreementData(
    bytes32 agreementID,
    address superToken,
    int96 flowRate,
    uint96 deposit
  ) private view returns (bool) {
    Agreement memory agreement = agreements[agreementID];
    int96 agreementFlowRate = int96(agreement.price / agreement.length);
    return
      agreementFlowRate == flowRate &&
      agreement.acceptedToken == superToken &&
      agreement.deposit == deposit;
  }
}
