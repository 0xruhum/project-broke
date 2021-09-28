pragma solidity ^0.8.0;

import "./utils/User.sol";

address constant SuperDAIAddress = 0xBF6201a6c48B56d8577eDD079b84716BB4918E8A;

contract CreateAgreement is BrokeTest {

  function testFail_needToApproveTokenFirst() public {
    alice.createAgreement(
      address(erc721Mock),
      1,
      SuperDAIAddress,
      10000,
      86400,
      1
    );
  }

  function testFail_needNFTAddress() public {
    alice.approve(address(this), 1);
    alice.createAgreement(
      address(0), // relevant part
      1,
      SuperDAIAddress,
      1000000000,
      86400,
      6000000
    );
  }

  function testFail_needAcceptedTokenAddress() public {
    alice.approve(address(this), 1);
    alice.createAgreement(
      address(erc721Mock),
      1,
      address(0), // relevant part
      1000000000,
      86400,
      6000000
    );
  }

  function test_valid() public {
    alice.approve(address(broke), 1);
    bytes32 hash = alice.createAgreement(
      address(erc721Mock),
      1,
      SuperDAIAddress,
      1000000000,
      86400,
      6000000
    );
    Agreement memory got = broke.getAgreement(hash);
    Agreement memory want = Agreement({
      buyer: address(0),
      seller: address(alice),
      nftAddress: address(erc721Mock),
      tokenID: 1,
      acceptedToken: SuperDAIAddress,
      price: 1000000000,
      length: 86400,
      deposit: 6000000,
      endDate: 0
    });
    assertEq(got, want);
  }
  
}

contract GetFlow is BrokeTest {

  function testFail_getFlow_invalidID() public {
    // should fail if there is no agreemet with the passed ID.
    //broke.getFlow("0xnjkandjsndjwnadn");
  }
}

contract AcceptAgreement is BrokeTest {

  function testFail_acceptAgremeent_alreadyAccepted() public {
    bytes32 hash = broke.createAgreement(
      address(erc721Mock),
      1,
      SuperDAIAddress,
      100,
      86400,
      100
    );
    // put the first call in try catch so we can verify that
    // it's not the one failing. If it fails we catch and log it
    // The function doesn't revert so the test should fail becasue
    // we use testFail.
    try broke.acceptAgreement{value: 100}(hash) {} catch Error(
      string memory error
    ) {
      emit log("Error: first call to accept agreement failed");
      return;
    }
    emit log_named_uint("end date", broke.getAgreement(hash).endDate);
    // first one should be successful, this one not.
    broke.acceptAgreement{value: 100}(hash);
  }
}

