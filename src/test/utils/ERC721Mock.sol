pragma solidity ^0.8.0;

contract ERC721Mock {
  mapping(uint256 => address) private owners;
  mapping(uint256 => address) private approvals;
  mapping(address => uint256) private balances;

  function approve(address to, uint256 tokenID) public {
    approvals[tokenID] = to;
  }

  function getApproved(uint256 tokenID) public view returns (address) {
    return approvals[tokenID];
  }

  function ownerOf(uint256 tokenID) public view returns (address) {
    return owners[tokenID];
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenID
  ) public {
    require(
      ownerOf(tokenID) == from || getApproved(tokenID) == from,
      "only owner can transfer"
    );

    // clear approval
    approve(address(0), tokenID);
    balances[from] -= 1;
    balances[to] += 1;
    owners[tokenID] = to;
  }

  function mint(address to, uint256 tokenID) public {
    balances[to] += 1;
    owners[tokenID] = to;
  }
}
