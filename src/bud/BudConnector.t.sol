pragma solidity ^0.5.12;

import { DSTest } from "ds-test/test.sol";
import { BudConnector, OSMLike, EndLike } from "./BudConnector.sol";

contract MockOSM {
    function peep() external view returns (bytes32, bool) {
        return ("0x11", true);
    }
}

contract FakeUser {
    function doAuthorize(BudConnector target, address addr) public {
        target.authorize(addr);
    }

    function doRevoke(BudConnector target, address addr) public {
        target.revoke(addr);
    }

    function doPeep(BudConnector target) public returns (bytes32, bool) {
        return target.peep();
    }
}

contract BudConnectorTest is DSTest {

    MockOSM osm;
    BudConnector budConnector;

    function setUp() public {
        osm = new MockOSM();
        budConnector = new BudConnector(OSMLike(address(osm)), EndLike(address(0)));
    }

    function testAuthToAuthorize() public {
        FakeUser user = new FakeUser();
        budConnector.authorize(address(user));

        assertTrue(budConnector.authorized(address(user)));
    }

    function testFailNonAuthToAuthorize() public {
        FakeUser user = new FakeUser();
        assertTrue(budConnector.authorized(address(user)) == false);

        // call must revert
        user.doAuthorize(budConnector, address(user));
    }

    function testAuthToRevoke() public {
        FakeUser user = new FakeUser();
        budConnector.authorize(address(user));
        assertTrue(budConnector.authorized(address(user)));

        budConnector.revoke(address(user));
        assertTrue(budConnector.authorized(address(user)) == false);
    }

    function testFailNonAuthToRevoke() public {
        FakeUser user = new FakeUser();
        assertTrue(budConnector.authorized(address(user)) == false);

        // call must revert
        user.doRevoke(budConnector, address(user));
    }

    function testAuthorizedToCallPeep() public {
        FakeUser user = new FakeUser();
        budConnector.authorize(address(user));
        assertTrue(budConnector.authorized(address(user)));

        (bytes32 price, bool flag) = user.doPeep(budConnector);
        assertEq32(price, "0x11");
        assertTrue(flag);
    }

    function testFailNonAuthorizedToCallPeep() public {
        FakeUser user = new FakeUser();
        assertTrue(budConnector.authorized(address(user)) == false);

        // call must revert
        user.doPeep(budConnector);
    }
}