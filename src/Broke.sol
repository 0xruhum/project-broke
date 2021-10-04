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
  IConstantFlowAgreementV1 internal immutable cfa;
  address[] internal validSuperTokens;
  // key: hash of sender + receiver
  mapping(bytes32 => Agreement) private agreements;
  mapping(address => uint256) public pendingWithdrawals;
  Agreement[] public pastAgreements;

  constructor(address _cfa, address[] memory _validSuperTokens) {
    require(_cfa != address(0), "cfa address needs to be defined");
    cfa = IConstantFlowAgreementV1(_cfa);
    validSuperTokens = _validSuperTokens;
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
      isSuperTokenAddress(_superfluidTokenAddress),
      "superfluidTokenAddress is not a valid super token address"
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
    Agreement storage agreement = agreements[id];
    require(
      isAgreementAcceptable(agreement),
      "The agreement is not available anymore"
    );
    // verify that the buyer has started a stream with the correct flow data
    (uint256 ts, int96 flowRate, , ) = cfa.getFlow(
      ISuperfluidToken(agreement.acceptedToken),
      msg.sender,
      agreement.seller
    );
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
    IERC721 nftContract = IERC721(agreement.nftAddress);
    nftContract.safeTransferFrom(
      agreement.seller,
      address(this),
      agreement.tokenID
    );
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
      sellerRetrieveToken(agreement, id);
    } else if (msg.sender == agreement.buyer) {
      buyerRetrieveToken(agreement, id);
    } else {
      revert("Caller has to be either buyer or seller");
    }
  }

  function buyerRetrieveToken(Agreement memory agreement, bytes32 id) private {
    // the buyer can only retrieve the token if the block's timestamp is
    // after the agreement's endDate
    if (block.timestamp > agreement.endDate) {
      endAgreement(agreement, agreement.buyer, id);
    }
  }

  function sellerRetrieveToken(Agreement memory agreement, bytes32 id) private {
    // if the agreement wasn't accepted by anybody yet,
    // the seller can simply take away the contract's approval
    // to transfer the token from their wallet.

    // We use a try catch in case the flow can not be retrieved from the
    // Superfluid contract. If that's the case, we have no way to validate
    // whether the buyer's flow is valid or even active.
    // As a safety meachnism we simply allow the seller to retrieve their token
    // in that case.
    try
      cfa.getFlow(
        ISuperfluidToken(agreement.acceptedToken),
        agreement.buyer,
        agreement.seller
      )
    returns (uint256 ts, int96 flowRate, uint256 deposit, uint256 owedDeposit) {
      int96 agreementFlowRate = int96(agreement.price / agreement.length);
      // Here we check 3 cases:
      //
      // Was the flow rate tampered with?
      // If the returned flowRate is not the samewe stored
      // in the agreement, that's the case.
      //
      // Was the flow closed and restarted at another time?
      // If that's the case, the ts of the flow and the agreement.length
      // wouldn't add up to the endDate we specified in the agreement.
      //
      // Either of the above cases have to be true AND the block.timestamp
      // has to be before the endDate we specified. That means, the
      // buyer has to have tampered with the flow while the agreement is still
      // active. If the endDate was reached the buyer can do with the flow whatever
      // they want.
      require(
        (flowRate != agreementFlowRate ||
          ts + agreement.length != agreement.endDate) &&
          block.timestamp < agreement.endDate,
        "The agreement is still valid and running. Cannot retrieve token"
      );
      endAgreement(agreement, agreement.seller, id);
    } catch {
      // can not retrieve flow that should have been started when the
      // agreement was accepted. Something seems to be wrong. So
      // we allow the seller to retrieve their token
      endAgreement(agreement, agreement.seller, id);
    }
  }

  /// @dev An agreement is acceptable if there is no buyer set and the
  /// contract is approved to transfer the NFT from the seller.
  /// @param agreement the agreement we check
  /// @return bool
  function isAgreementAcceptable(Agreement memory agreement)
    public
    view
    returns (bool)
  {
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
  /// @param id the ID of the agreement
  /// @return (uint256, int96, uint256, uint256) the flow data
  function getFlow(bytes32 id)
    external
    view
    returns (
      uint256,
      int96,
      uint256,
      uint256
    )
  {
    Agreement memory a = agreements[id];
    return cfa.getFlow(ISuperfluidToken(a.acceptedToken), a.buyer, a.seller);
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

  function endAgreement(
    Agreement memory agreement,
    address to,
    bytes32 id
  ) private {
    // we delete the agreement from the mapping of currently active agreements.
    // Thus, neither the buyer nor seller can call "retrieveToken()" twice.
    // Otherwise, they could call it again and again and increase their
    // pendingWithdrawal and therefore drain the contract.
    delete agreements[id];
    // keep track of all the past agreements.
    pastAgreements.push(agreement);

    IERC721 nftContract = IERC721(agreement.nftAddress);
    nftContract.safeTransferFrom(address(this), to, agreement.tokenID);

    // allow withdrawing the deposit
    pendingWithdrawals[to] += agreement.deposit;
  }

  function withdrawDeposit() public {
    uint256 amount = pendingWithdrawals[msg.sender];
    require(amount > 0, "sender has no pending withdrawal");

    pendingWithdrawals[msg.sender] = 0;
    payable(msg.sender).transfer(amount);
  }

  function isSuperTokenAddress(address token) internal view returns (bool) {
    for (uint256 i = 0; i < validSuperTokens.length; i++) {
      if (validSuperTokens[i] == token) return true;
    }
    return false;
  }
}
