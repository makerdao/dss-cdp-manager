pragma solidity ^0.5.12;

import { DSTest } from "ds-test/test.sol";
import { OSMConnector, OSMLike } from "./OSMConnector.sol";

contract MockOSM {
    function peep() external view returns (bytes32, bool) {
        return ("0x11", true);
    }
}

contract FakeUser {
    function doAuthorize(OSMConnector target, address addr) public {
        target.authorize(addr);
    }

    function doRevoke(OSMConnector target, address addr) public {
        target.revoke(addr);
    }

    function doPeep(OSMConnector target) public returns (bytes32, bool) {
        return target.peep();
    }
}

contract OSMConnectorTest is DSTest {

    MockOSM osm;
    OSMConnector osmConnector;

    function setUp() public {
        osm = new MockOSM();
        osmConnector = new OSMConnector(OSMLike(address(osm)));
    }

    function testAuthToAuthorize() public {
        FakeUser user = new FakeUser();
        osmConnector.authorize(address(user));

        assertTrue(osmConnector.authorized(address(user)));
    }

    function testFailNonAuthToAuthorize() public {
        FakeUser user = new FakeUser();
        assertTrue(osmConnector.authorized(address(user)) == false);

        // call must revert
        user.doAuthorize(osmConnector, address(user));
    }

    function testAuthToRevoke() public {
        FakeUser user = new FakeUser();
        osmConnector.authorize(address(user));
        assertTrue(osmConnector.authorized(address(user)));

        osmConnector.revoke(address(user));
        assertTrue(osmConnector.authorized(address(user)) == false);
    }

    function testFailNonAuthToRevoke() public {
        FakeUser user = new FakeUser();
        assertTrue(osmConnector.authorized(address(user)) == false);

        // call must revert
        user.doRevoke(osmConnector, address(user));
    }

    function testAuthorizedToCallPeep() public {
        FakeUser user = new FakeUser();
        osmConnector.authorize(address(user));
        assertTrue(osmConnector.authorized(address(user)));

        (bytes32 price, bool flag) = user.doPeep(osmConnector);
        assertEq32(price, "0x11");
        assertTrue(flag);
    }

    function testFailNonAuthorizedToCallPeep() public {
        FakeUser user = new FakeUser();
        assertTrue(osmConnector.authorized(address(user)) == false);

        // call must revert
        user.doPeep(osmConnector);
    }
}