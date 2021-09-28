// Contract to simulate a user since each user will have their own address
pragma solidity ^0.8.0;
import "ds-test/test.sol";

import "./ERC721Mock.sol";
import "../../Broke.sol";

contract User {
  Broke internal broke;
  ERC721Mock internal erc721Mock;
  constructor(Broke _broke, ERC721Mock _erc721Mock) {
    broke = _broke;
    erc721Mock = _erc721Mock;
  }

  function approve(address to, uint256 tokenID) public {
    erc721Mock.approve(to, tokenID);
  }

  function createAgreement(
    address _nftAddress,
    uint256 _tokenID,
    address _superfluidTokenAddress,
    uint256 _price,
    uint256 _length,
    uint256 _deposit
  ) public returns (bytes32) {
    return broke.createAgreement(
      _nftAddress,
      _tokenID,
      _superfluidTokenAddress,
      _price,
      _length,
      _deposit
    );
  }
}

contract BrokeTest is DSTest {
  Broke internal broke;
  ERC721Mock internal erc721Mock;

  User internal alice;
  User internal bob;

  function setUp() public virtual {
    broke = new Broke(
      address(0xF2B4E81ba39F5215Db2e05B2F66f482BB8e87FD2),
      address(0xaD2F1f7cd663f6a15742675f975CcBD42bb23a88)
    );
    erc721Mock = new ERC721Mock();
    alice = new User(broke, erc721Mock);
    bob = new User(broke, erc721Mock);
  }

  function assertEq(Agreement memory got, Agreement memory want) internal {
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
