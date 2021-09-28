pragma solidity ^0.8.0;

contract ERC721Mock {
  mapping(uint256 => address) public approvals;

  function approve(address to, uint256 tokenID) external {
    approvals[tokenID] = to;
  }

  function getApproved(uint256 tokenID) external returns (address) {
    return approvals[tokenID];
  }
}
