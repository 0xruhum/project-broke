// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import "./ERC721Mock.sol";
import "../../Broke.sol";

// Contract to simulate a user since each user will have their own address
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
  ) public returns (uint256) {
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

  function acceptAgreement(uint256 id) public payable {
    return broke.acceptAgreement{value: msg.value}(id);
  }

  function retrieveToken(uint256 id) public {
    return broke.retrieveToken(id);
  }

  function withdrawDeposit() public {
    return broke.withdrawDeposit();
  }

  // solhint-disable-next-line no-empty-blocks
  receive() external payable {}
}


