// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Agreement {
  address immutable public buyer;
  address immutable public seller;
  // the total price that the buyer has to pay
  uint immutable public price;
  // the date at which the dept will be paid off
  uint immutable public endDate; 

  constructor(
    address _buyer,
    address _seller,
    uint _price,
    uint _endDate
  ) {
    buyer = _buyer;
    seller = _seller;
    price = _price;
    endDate = _endDate;
  }

  /// @notice Allows seller to retrieve the token if the buyer closed the stream to early
  /// or ran out of funds.
  /// Allows buyer to retrieve token if the debt was fully paid off. Also closes the stream
  /// automatically after the buyer retrieved the token.
  function retrieveToken() external {
    // we could use a modifier to only allow the buyer and seller to call the function.
    // But, then we would have to still sepearte between seller and buyer
    // since both take a different path. Thus, using a modifier is gas waste here.
    if (msg.sender == seller) {

    } else if (msg.sender == buyer) {

      // should automatically close the stream
    } else {
      revert("Caller has to be either buyer or seller");
    }
  }

  /// @notice Allows the buyer to close the stream. Doesn't matter if the debt was paid off
  /// fully or not.
  function closeStream() public onlyBuyer {

  }

  function isSeller(address addr) internal view returns (bool) {
    return addr == seller;
  }

  function isBuyer(address addr) internal view returns (bool) {
    return addr == buyer;
  }

  modifier onlyBuyer() {
    require(msg.sender == buyer, "Not buyer");
    _;
  }
}
