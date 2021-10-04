// Contract to simulate a user since each user will have their own address
pragma solidity ^0.8.0;
import "ds-test/test.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import "./ERC721Mock.sol";
import "./Hevm.sol";
import "../../Broke.sol";

contract User {
  Broke internal broke;
  ERC721Mock internal erc721Mock;
  ISuperfluid internal superfluid;
  IConstantFlowAgreementV1 internal cfa;

  constructor(Broke _broke, ERC721Mock _erc721Mock) {
    broke = _broke;
    erc721Mock = _erc721Mock;
    superfluid = ISuperfluid(0xF2B4E81ba39F5215Db2e05B2F66f482BB8e87FD2);
    cfa = IConstantFlowAgreementV1(0xaD2F1f7cd663f6a15742675f975CcBD42bb23a88);
  }

  function approve(address to, uint256 tokenID) public {
    erc721Mock.approve(to, tokenID);
  }

  function createAgreement(
    address _nftAddress,
    uint256 _tokenID,
    address _superfluidTokenAddress,
    uint96 _price,
    uint96 _length,
    uint256 _deposit
  ) public returns (bytes32) {
    return
      broke.createAgreement(
        _nftAddress,
        _tokenID,
        _superfluidTokenAddress,
        _price,
        _length,
        _deposit
      );
  }

  function createFlow(
    address superToken,
    address receiver,
    int96 flowRate
  ) public {
    superfluid.callAgreement(
      cfa,
      abi.encodeWithSelector(
        cfa.createFlow.selector,
        superToken,
        receiver,
        flowRate,
        new bytes(0)
      ),
      "0x"
    );
  }

  function updateFlow(
    address superToken,
    address receiver,
    int96 flowRate
  ) public {
    superfluid.callAgreement(
      cfa,
      abi.encodeWithSelector(
        cfa.updateFlow.selector,
        superToken,
        receiver,
        flowRate,
        new bytes(0)
      ),
      "0x"
    );
  }

  function deleteFlow(address superToken, address receiver) public {
    superfluid.callAgreement(
      cfa,
      abi.encodeWithSelector(
        cfa.deleteFlow.selector,
        superToken,
        address(this),
        receiver,
        new bytes(0)
      ),
      "0x"
    );
  }

  function acceptAgreement(bytes32 hash) public payable {
    return broke.acceptAgreement{value: msg.value}(hash);
  }

  function retrieveToken(bytes32 hash) public {
    return broke.retrieveToken(hash);
  }

  function withdrawDeposit() public {
    return broke.withdrawDeposit();
  }

  // solhint-disable-next-line no-empty-blocks
  receive() external payable {}
}

contract BrokeTest is DSTest {
  Hevm internal constant hevm = Hevm(HEVM_ADDRESS);
  Broke internal broke;
  ERC721Mock internal erc721Mock;

  User internal alice;
  User internal bob;

  function setUp() public virtual {
    // see https://docs.superfluid.finance/superfluid/networks/networks
    address[] memory validSuperTokens = new address[](4);
    // initializing dynamic arrays:
    // https://docs.soliditylang.org/en/latest/types.html#array-literals
    validSuperTokens[0] = 0xBF6201a6c48B56d8577eDD079b84716BB4918E8A;
    validSuperTokens[1] = 0x2dC36872a445adF0bFf63cc0eeee52A2b801625f;
    validSuperTokens[2] = 0xC5191A51982983B8105eC4Fbbbf35b9466EE0179;
    validSuperTokens[3] = 0x6fC99F5591b51583ba15A8C2572408257A1D2797;
    broke = new Broke(
      0xaD2F1f7cd663f6a15742675f975CcBD42bb23a88,
      validSuperTokens
    );

    erc721Mock = new ERC721Mock();
    alice = new User(broke, erc721Mock);
    bob = new User(broke, erc721Mock);
    // mint the token we will use for the tests laeer on
    erc721Mock.mint(address(bob), 1);
  }

  // solhint-disable-next-line code-complexity
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

  // solhint-disable-next-line no-empty-blocks
  receive() external payable {}
}
