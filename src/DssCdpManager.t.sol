pragma solidity ^0.4.24;

import "ds-test/test.sol";

import "./DssCdpManager.sol";

contract DssCdpManagerTest is DSTest {
    DssCdpManager manager;

    function setUp() public {
        manager = new DssCdpManager();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
