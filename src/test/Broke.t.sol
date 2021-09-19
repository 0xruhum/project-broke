pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../Broke.sol";

contract BrokeTest is DSTest {
  Broke broke;
  function setUp() public {
    // placeholder addresses
    broke = new Broke(address("0x92"), address("0x02"));        
  }

  function test_createAgreement() public {
    uint length = 86400; // 1 day

    Agreement memory agreement = Agreement({
      buyer: address(0),
      seller: address(this),
      nftAddress: address("0x2312"),
      tokenID: 1,
      acceptedToken: address("0x231"),
      price: 1000000000000000000,
      endDate: block.timestamp + length,
      deposit: 50000000
    });

    bytes32 hash = broke.createAgreement(
      agreement.nftAddress,
      agreement.tokenID,
      agreement.acceptedToken,
      agreement.price,
      length,
      agreement.deposit
    );

    assertEq(broke.agreements[hash], agreement);
  }

  receive() external payable {}
}
