pragma solidity ^0.5.12;

import { DSTest } from "ds-test/test.sol";
import { BudConnector, OSMLike, EndLike } from "./BudConnector.sol";

contract MockOSM {
    function peep() external view returns (bytes32, bool) {
        return ("0x11", true);
    }
}

contract MockEnd {
    MockSpot public spot = new MockSpot();
}

contract MockSpot {
    MockPip pip = new MockPip();
    function ilks(bytes32 ilk) public returns (MockPip, uint) {
        ilk; // shh compiler warning
        return (pip, 0);
    }
}

contract MockPip {
    function read() external view returns (bytes32) {
        return "0x22";
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

    function doRead(BudConnector target) public returns (bytes32) {
        bytes32 fakeIlk = "0xff";
        return target.read(fakeIlk);
    }
}

contract BudConnectorTest is DSTest {

    MockOSM osm;
    MockEnd end;
    BudConnector budConnector;

    function setUp() public {
        osm = new MockOSM();
        end = new MockEnd();
        budConnector = new BudConnector(OSMLike(address(osm)), EndLike(address(end)));
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

    function testAuthorizedToCallRead() public {
        FakeUser user = new FakeUser();
        budConnector.authorize(address(user));
        assertTrue(budConnector.authorized(address(user)));

        bytes32 price = user.doRead(budConnector);
        assertEq32(price, "0x22");
    }

    function testFailNonAuthorizedToCallRead() public {
        FakeUser user = new FakeUser();
        assertTrue(budConnector.authorized(address(user)) == false);

        // call must revert
        user.doRead(budConnector);
    }
}