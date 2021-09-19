pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../Broke.sol";

contract ERC721Mock {
  mapping(uint => address) public approvals;
  function approve(address to, uint tokenID) external {
    approvals[tokenID] = to;
  }
  function getApproved(uint tokenID) external returns (address) {
    return approvals[tokenID];
  }
}

contract BrokeTest is DSTest {
  Broke broke;
  ERC721Mock erc721Mock;

  function setUp() public {
    // placeholder addresses
    broke = new Broke(address(0x92), address(0x02));        
    erc721Mock = new ERC721Mock();
  }

  function test_createAgreement() public {
    uint length = 86400; // 1 day

    Agreement memory agreement = Agreement({
      buyer: address(0),
      seller: address(this),
      nftAddress: address(erc721Mock),
      tokenID: 1,
      acceptedToken: address(0x231),
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
    Agreement memory got = broke.getAgreement(hash);

    assertEq(agreement, got);
  }

  function testFail_createAgreement_needNFTAddress() public {
    uint length = 86400; // 1 day

    Agreement memory agreement = Agreement({
      buyer: address(0),
      seller: address(this),
      nftAddress: address(0),
      tokenID: 1,
      acceptedToken: address(0x231),
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
    Agreement memory got = broke.getAgreement(hash);

    assertEq(agreement, got);
  }

  function testFail_createAgreement_needAcceptedTokenAddress() public {
    uint length = 86400; // 1 day

    Agreement memory agreement = Agreement({
      buyer: address(0),
      seller: address(this),
      nftAddress: address(erc721Mock),
      tokenID: 1,
      acceptedToken: address(0),
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
    Agreement memory got = broke.getAgreement(hash);

    assertEq(agreement, got);
  }

  function assertEq(Agreement memory want, Agreement memory got) internal {
    if (want.buyer != got.buyer) {
      emit log("Error: Agreement.buyer mismatch");
      emit log_named_address(" Expected", want.buyer);
      emit log_named_address(" Actual", got.buyer);
      fail();
    } else if (want.seller != got.seller) {
      emit log("Error: Agreement.seller mismatch");
      emit log_named_address(" Expected", want.seller);
      emit log_named_address(" Actual", got.seller);
      fail();
    } else if (want.nftAddress != got.nftAddress) {
      emit log("Error: Agreement.nftAddress mismatch");
      emit log_named_address(" Expected", want.nftAddress);
      emit log_named_address(" Actual", got.nftAddress);
      fail();
    } else if (want.tokenID != got.tokenID) {
      emit log("Error: Agreement.tokenID mismatch");
      emit log_named_uint(" Expected", want.tokenID);
      emit log_named_uint(" Actual", got.tokenID);
      fail();
    } else if (want.acceptedToken != got.acceptedToken) {
      emit log("Error: Agreement.acceptedToken mismatch");
      emit log_named_address(" Expected", want.acceptedToken);
      emit log_named_address(" Actual", got.acceptedToken);
      fail();
    } else if (want.price != got.price) {
      emit log("Error: Agreement.price mismatch");
      emit log_named_uint(" Expected", want.price);
      emit log_named_uint(" Actual", got.price);
      fail();
    } else if (want.endDate != got.endDate) {
      emit log("Error: Agreement.endDate mismatch");
      emit log_named_uint(" Expected", want.endDate);
      emit log_named_uint(" Actual", got.endDate);
      fail();
    } else if (want.deposit != got.deposit) {
      emit log("Error: Agreement.deposit mismatch");
      emit log_named_uint(" Expected", want.deposit);
      emit log_named_uint(" Actual", got.deposit);
      fail();
    }
  }
  receive() external payable {}
}