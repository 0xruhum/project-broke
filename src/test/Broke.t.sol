// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./utils/BrokeTest.sol";

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

  function testFail_acceptedTokenCannotBeNull() public {
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

  function testFail_acceptedTokenHasToBeSuperToken() public {
    alice.approve(address(this), 1);
    alice.createAgreement(
      address(erc721Mock),
      1,
      0xbe49ac1EadAc65dccf204D4Df81d650B50122aB2, // relevant part
      1000000000,
      86400,
      6000000
    );
  }

  function test_valid() public {
    alice.approve(address(broke), 1);
    uint256 id = alice.createAgreement(
      address(erc721Mock),
      1,
      SuperDAIAddress,
      1000000000,
      86400,
      6000000
    );
    Agreement memory got = broke.getAgreement(id);
    Agreement memory want = Agreement({
      buyer: address(0),
      seller: address(alice),
      nftAddress: address(erc721Mock),
      tokenID: 1,
      acceptedToken: SuperDAIAddress,
      price: 1000000000,
      length: 86400,
      deposit: 6000000,
      createdAt: block.timestamp,
      endDate: 0
    });
    assertEq(got, want);
  }
}

contract GetFlow is BrokeTest {
  uint96 private price;
  uint96 private length;
  uint256 private id;

  function setupAgreement() private {
    bob.approve(address(broke), 1);
    price = 1 * 1e18;
    length = 86400; // 1 day
    id = bob.createAgreement(
      address(erc721Mock),
      1,
      SuperDAIAddress,
      price,
      length,
      100
    );
  }

  function test_shouldReturnFlowData() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);
    (uint256 ts, int96 flowRate, , ) = broke.getFlow(id);

    // we don't specify the deposit here so we don't check for that.
    assertEq(ts, block.timestamp);
    assertEq(flowRate, int96(price / length));
  }
}

contract AcceptAgreement is BrokeTest {
  uint96 private price;
  uint96 private length;
  uint256 private id;

  function setupAgreement() private {
    bob.approve(address(broke), 1);
    price = 1 * 1e18;
    length = 86400; // 1 day
    id = bob.createAgreement(
      address(erc721Mock),
      1,
      SuperDAIAddress,
      price,
      length,
      100
    );
  }

  function test_valid() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);
  }

  function testFail_alreadyAccepted() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    // put the first call in try catch so we can verify that
    // it's not the one failing. If it fails we catch and log it
    // The function doesn't revert so the test should fail becasue
    // we use testFail.
    try alice.acceptAgreement{value: 100}(id) {} catch Error(string memory) {
      emit log("Error: first call to accept agreement failed");
      return;
    }
    // first one should be successful, this one not.
    alice.acceptAgreement{value: 100}(id);
  }
}

contract SellerRetrieveToken is BrokeTest {
  uint96 private price;
  uint96 private length;
  uint256 private id;
  uint256 private tokenID;

  function setupAgreement() private {
    bob.approve(address(broke), 1);
    price = 1 * 1e18;
    length = 86400; // 1 day
    tokenID = 1;
    id = bob.createAgreement(
      address(erc721Mock),
      tokenID,
      SuperDAIAddress,
      price,
      length,
      100
    );
  }

  function test_cannotGetFlowData() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);

    // alice deletes the flow
    alice.deleteFlow(SuperDAIAddress, address(bob));
    bob.retrieveToken(id);

    assertEq(erc721Mock.ownerOf(tokenID), address(bob));
  }

  function test_flowRateChanged() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);

    // buyer updates flowRate in the middle of the agreement
    alice.updateFlow(SuperDAIAddress, address(bob), 1);
    bob.retrieveToken(id);

    assertEq(erc721Mock.ownerOf(tokenID), address(bob));
  }

  function test_flowTimestampDoesNotMatch() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);

    // buyer modifies the initial flow in any way => timestamp shouldn't match
    hevm.warp(block.timestamp + 1);
    alice.updateFlow(SuperDAIAddress, address(bob), int96(price / length));
    bob.retrieveToken(id);

    assertEq(erc721Mock.ownerOf(tokenID), address(bob));
  }

  function test_canWithdrawDeposit() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);

    // alice deletes the flow
    alice.updateFlow(SuperDAIAddress, address(bob), 1);
    bob.retrieveToken(id);

    bob.withdrawDeposit();
    assertEq(broke.pendingWithdrawals(address(bob)), 0);
    assertEq(address(bob).balance, 100);
  }

  function testFail_cannotWithdrawTwice() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);

    // alice deletes the flow
    alice.updateFlow(SuperDAIAddress, address(bob), 1);
    bob.retrieveToken(id);

    bob.withdrawDeposit();
    assertEq(broke.pendingWithdrawals(address(bob)), 0);
    assertEq(address(bob).balance, 100);

    bob.withdrawDeposit();
  }

  function testFail_cannotRetrieveTwice() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);

    // alice deletes the flow
    alice.updateFlow(SuperDAIAddress, address(bob), 1);
    bob.retrieveToken(id);
    assertEq(erc721Mock.ownerOf(tokenID), address(bob));

    bob.retrieveToken(id);
  }

  function testFail_flowAndAgreementValid() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);

    bob.retrieveToken(id);
    assertEq(erc721Mock.ownerOf(tokenID), address(broke));
  }

  function testFail_agreementOver() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);
    // set block timestamp after the end date
    hevm.warp(block.timestamp + length + 1);
    // delete flow since it was paid off.
    alice.deleteFlow(SuperDAIAddress, address(bob));

    // bob shouldn't be able to retrieve his token.
    bob.retrieveToken(id);
    assertEq(erc721Mock.ownerOf(tokenID), address(broke));
  }
}

contract BuyerRetrieveToken is BrokeTest {
  uint96 private price;
  uint96 private length;
  uint256 private id;
  uint256 private tokenID;

  function setupAgreement() private {
    bob.approve(address(broke), 1);
    price = 1 * 1e18;
    length = 86400; // 1 day
    tokenID = 1;
    id = bob.createAgreement(
      address(erc721Mock),
      tokenID,
      SuperDAIAddress,
      price,
      length,
      100
    );
  }

  function test_blockAfterEndDate() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);

    // set block timestamp after the end date
    hevm.warp(block.timestamp + length + 1);

    alice.retrieveToken(id);
    assertEq(erc721Mock.ownerOf(tokenID), address(alice));
  }

  function testFail_cannotRetrieveBeforeEndDate() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);

    alice.retrieveToken(id);
    assertEq(erc721Mock.ownerOf(tokenID), address(alice));
  }

  function test_canWithdrawDeposit() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);

    // set block timestamp after the end date
    hevm.warp(block.timestamp + length + 1);

    alice.retrieveToken(id);

    alice.withdrawDeposit();
    assertEq(broke.pendingWithdrawals(address(alice)), 0);
    assertEq(address(alice).balance, 100);
  }

  function testFail_cannotWithdrawTwice() public {
    setupAgreement();
    alice.createFlow(SuperDAIAddress, address(bob), int96(price / length));
    alice.acceptAgreement{value: 100}(id);

    // set block timestamp after the end date
    hevm.warp(block.timestamp + length + 1);

    alice.retrieveToken(id);

    alice.withdrawDeposit();
    assertEq(broke.pendingWithdrawals(address(alice)), 0);
    assertEq(address(alice).balance, 100);

    alice.withdrawDeposit();
  }
}
