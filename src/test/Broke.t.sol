pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../Broke.sol";

contract ERC721Mock {
    mapping(uint256 => address) public approvals;

    function approve(address to, uint256 tokenID) external {
        approvals[tokenID] = to;
    }

    function getApproved(uint256 tokenID) external returns (address) {
        return approvals[tokenID];
    }
}

contract BrokeTest is DSTest {
    Broke broke;
    ERC721Mock erc721Mock;

    function setUp() public {
        // see https://docs.superfluid.finance/superfluid/networks/networks
        // for contract addresses
        broke = new Broke(
            address(0xF2B4E81ba39F5215Db2e05B2F66f482BB8e87FD2),
            address(0xaD2F1f7cd663f6a15742675f975CcBD42bb23a88)
        );
        erc721Mock = new ERC721Mock();
    }

    function test_createAgreement() public {
        Agreement memory agreement = Agreement({
            buyer: address(0),
            seller: address(this),
            nftAddress: address(erc721Mock),
            tokenID: 1,
            acceptedToken: address(0x231),
            price: 1000000000000000000,
            length: 86400, // 1 day
            endDate: 0,
            deposit: 50000000
        });

        bytes32 hash = broke.createAgreement(
            agreement.nftAddress,
            agreement.tokenID,
            agreement.acceptedToken,
            agreement.price,
            agreement.length,
            agreement.deposit
        );
        Agreement memory got = broke.getAgreement(hash);

        assertEq(got, agreement);
    }

    function testFail_createAgreement_needNFTAddress() public {
        bytes32 hash = broke.createAgreement(
            address(0), // relevant part
            1,
            address(0x231),
            1000000000,
            86400,
            6000000
        );
        broke.getAgreement(hash);
    }

    function testFail_createAgreement_needAcceptedTokenAddress() public {
        bytes32 hash = broke.createAgreement(
            address(erc721Mock),
            1,
            address(0), // relevant part
            1000000000,
            86400,
            6000000
        );
        broke.getAgreement(hash);
    }

    function test_acceptAgreement_createsStream() public {
        bytes32 hash = broke.createAgreement(
            address(erc721Mock),
            1,
            // fDAIx address on Ropsten Testnet
            address(0xBF6201a6c48B56d8577eDD079b84716BB4918E8A),
            100,
            86400,
            100
        );
        broke.acceptAgreement{value: 100}(hash);
        (
            uint256 ts,
            int96 flowRate,
            uint256 deposit,
            uint256 owedDeposit
        ) = broke.getFlow(hash);
        assertEq(ts, block.timestamp);
        assertEq(flowRate, 86400);
        assertEq(deposit, 100);
        assertEq(owedDeposit, 0);
    }

    function testFail_getFlow_invalidID() public {
        // should fail if there is no agreemet with the passed ID.
        broke.getFlow("0xnjkandjsndjwnadn");
    }

    function testFail_acceptAgremeent_alreadyAccepted() public {
        bytes32 hash = broke.createAgreement(
            address(erc721Mock),
            1,
            // fDAIx address on Ropsten Testnet
            address(0xBF6201a6c48B56d8577eDD079b84716BB4918E8A),
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
