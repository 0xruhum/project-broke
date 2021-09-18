// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// INTERNAL IMPORTS
import "./Agreement.sol";

contract Broke {
  mapping(bytes32 => Agreement) public agreements;

  /// @notice creates a new agreement which a buyer can accept.
  /// @dev verifies that the user actually owns the token they're trying to sell.
  /// @param token the token which the caller wants to sell
  /// @param price the total price for which they want to sell it
  /// @param length the total length in seconds of the agreement.
  /// @param deposit the deposit the seller expects from the buyer.
  /// @return the bytes32 hash identifier of the agreement.
  /// TODO: use correct token type
  function createAgreement(bytes32 token, uint price, uint length, uint deposit) external returns (bytes32) {

  }

  /// @notice accepts an existing agreement and starts a stream from the buyer to the seller
  /// @dev verifies that the seller still owns the item.
  /// @param id the ID of the agreement they want to accept
  function acceptAgreement(bytes32 id) external {

  }
}
