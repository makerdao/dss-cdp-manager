pragma solidity >= 0.5.0;

import { DssDeployTestBase } from "dss-deploy/DssDeploy.t.base.sol";
import "./DssCdpManager.sol";

contract FakeUser {
    function doMove(
        DssCdpManager manager,
        bytes12 cdp,
        address dst
    ) public {
        manager.move(cdp, dst);
    }

    function doFrob(
        DssCdpManager manager,
        address pit,
        bytes12 cdp,
        bytes32 ilk,
        int dink,
        int dart
    ) public {
        manager.frob(pit, cdp, ilk, dink, dart);
    }
}

contract DssCdpManagerTest is DssDeployTestBase {
    DssCdpManager manager;
    FakeUser user;

    function setUp() public {
        super.setUp();
        manager = new DssCdpManager();
        user = new FakeUser();
    }

    function testOpenCDP() public {
        bytes12 cdp = manager.open();
        assertEq(bytes32(cdp), bytes32(bytes12(uint96(1))));
        assertEq(manager.lads(cdp), address(this));
    }

    function testOpenCDPOtherAddress() public {
        bytes12 cdp = manager.open(address(123));
        assertEq(manager.lads(cdp), address(123));
    }

    function testTransferCDP() public {
        bytes12 cdp = manager.open();
        manager.move(cdp, address(123));
        assertEq(manager.lads(cdp), address(123));
    }

    function testTransferAllowed() public {
        bytes12 cdp = manager.open();
        manager.allow(cdp, address(user), true);
        user.doMove(manager, cdp, address(123));
        assertEq(manager.lads(cdp), address(123));
    }

    function testFailTransferNotAllowed() public {
        bytes12 cdp = manager.open();
        user.doMove(manager, cdp, address(123));
    }

    function testFailTransferNotAllowed2() public {
        bytes12 cdp = manager.open();
        manager.allow(cdp, address(user), true);
        manager.allow(cdp, address(user), false);
        user.doMove(manager, cdp, address(123));
    }

    function testFailTransferNotAllowed3() public {
        bytes12 cdp = manager.open();
        bytes12 cdp2 = manager.open();
        manager.allow(cdp2, address(user), true);
        user.doMove(manager, cdp, address(123));
    }

    function testFailTransferToSameOwner() public {
        bytes12 cdp = manager.open();
        manager.move(cdp, address(this));
    }

    function testDoubleLinkedList() public {
        bytes12 cdp1 = manager.open();
        bytes12 cdp2 = manager.open();
        bytes12 cdp3 = manager.open();

        bytes12 cdp4 = manager.open(address(user));
        bytes12 cdp5 = manager.open(address(user));
        bytes12 cdp6 = manager.open(address(user));
        bytes12 cdp7 = manager.open(address(user));

        assertEq(manager.count(address(this)), 3);
        assertTrue(manager.last(address(this)) == cdp3);
        (bytes12 prev, bytes12 next) = manager.cdps(cdp1);
        assertTrue(prev == "");
        assertTrue(next == cdp2);
        (prev, next) = manager.cdps(cdp2);
        assertTrue(prev == cdp1);
        assertTrue(next == cdp3);
        (prev, next) = manager.cdps(cdp3);
        assertTrue(prev == cdp2);
        assertTrue(next == "");

        assertEq(manager.count(address(user)), 4);
        assertTrue(manager.last(address(user)) == cdp7);
        (prev, next) = manager.cdps(cdp4);
        assertTrue(prev == "");
        assertTrue(next == cdp5);
        (prev, next) = manager.cdps(cdp5);
        assertTrue(prev == cdp4);
        assertTrue(next == cdp6);
        (prev, next) = manager.cdps(cdp6);
        assertTrue(prev == cdp5);
        assertTrue(next == cdp7);
        (prev, next) = manager.cdps(cdp7);
        assertTrue(prev == cdp6);
        assertTrue(next == "");

        manager.move(cdp2, address(user));

        assertEq(manager.count(address(this)), 2);
        assertTrue(manager.last(address(this)) == cdp3);
        (prev, next) = manager.cdps(cdp1);
        assertTrue(next == cdp3);
        (prev, next) = manager.cdps(cdp3);
        assertTrue(prev == cdp1);

        assertEq(manager.count(address(user)), 5);
        assertTrue(manager.last(address(user)) == cdp2);
        (prev, next) = manager.cdps(cdp7);
        assertTrue(next == cdp2);
        (prev, next) = manager.cdps(cdp2);
        assertTrue(prev == cdp7);
        assertTrue(next == "");

        user.doMove(manager, cdp2, address(this));

        assertEq(manager.count(address(this)), 3);
        assertTrue(manager.last(address(this)) == cdp2);
        (prev, next) = manager.cdps(cdp3);
        assertTrue(next == cdp2);
        (prev, next) = manager.cdps(cdp2);
        assertTrue(prev == cdp3);
        assertTrue(next == "");

        assertEq(manager.count(address(user)), 4);
        assertTrue(manager.last(address(user)) == cdp7);
        (prev, next) = manager.cdps(cdp7);
        assertTrue(next == "");
    }

    function testGetCdps() public {
        bytes12 cdp1 = manager.open();
        bytes12 cdp2 = manager.open();
        bytes12 cdp3 = manager.open();

        bytes12[] memory cdps = manager.getCdps(address(this));
        assertEq(cdps.length, 3);
        assertTrue(cdps[0] == cdp3);
        assertTrue(cdps[1] == cdp2);
        assertTrue(cdps[2] == cdp1);

        manager.move(cdp2, address(user));
        cdps = manager.getCdps(address(this));
        assertEq(cdps.length, 2);
        assertTrue(cdps[0] == cdp3);
        assertTrue(cdps[1] == cdp1);
    }

    function testFrob() public {
        deploy();
        bytes12 cdp = manager.open();
        ethJoin.join.value(1 ether)(manager.getUrn(cdp));
        manager.frob(address(pit), cdp, "ETH", 1 ether, 50 ether);
        assertEq(vat.dai(manager.getUrn(cdp)), 50 ether * ONE);
        assertEq(dai.balanceOf(address(this)), 0);
        manager.exit(address(daiJoin), cdp, address(this), 50 ether);
        assertEq(dai.balanceOf(address(this)), 50 ether);
    }

    function testFrobAllowed() public {
        deploy();
        bytes12 cdp = manager.open();
        ethJoin.join.value(1 ether)(manager.getUrn(cdp));
        manager.allow(cdp, address(user), true);
        user.doFrob(manager, address(pit), cdp, "ETH", 1 ether, 50 ether);
        assertEq(vat.dai(manager.getUrn(cdp)), 50 ether * ONE);
    }

    function testFailFrobNotAllowed() public {
        deploy();
        bytes12 cdp = manager.open();
        ethJoin.join.value(1 ether)(manager.getUrn(cdp));
        user.doFrob(manager, address(pit), cdp, "ETH", 1 ether, 50 ether);
    }

    function testFrobGetCollateralBack() public {
        deploy();
        bytes12 cdp = manager.open();
        ethJoin.join.value(1 ether)(manager.getUrn(cdp));
        manager.frob(address(pit), cdp, "ETH", 1 ether, 50 ether);
        manager.frob(address(pit), cdp, "ETH", -int(1 ether), -int(50 ether));
        assertEq(vat.dai(manager.getUrn(cdp)), 0);
        assertEq(vat.gem("ETH", manager.getUrn(cdp)), 1 ether * ONE);
        uint prevBalance = address(this).balance;
        manager.exit(address(ethJoin), cdp, address(this), 1 ether);
        assertEq(address(this).balance, prevBalance + 1 ether);
    }
}
