pragma solidity >= 0.5.0;

import { DssDeployTestBase } from "dss-deploy/DssDeploy.t.base.sol";
import "./DssCdpManager.sol";

contract FakeUser {
    function doMove(
        DssCdpManager manager,
        uint cdp,
        address dst
    ) public {
        manager.move(cdp, dst);
    }

    function doFrob(
        DssCdpManager manager,
        address vat,
        uint cdp,
        int dink,
        int dart
    ) public {
        manager.frob(vat, cdp, dink, dart);
    }
}

contract DssCdpManagerTest is DssDeployTestBase {
    DssCdpManager manager;
    GetCdps getCdps;
    FakeUser user;

    function setUp() public {
        super.setUp();
        manager = new DssCdpManager();
        getCdps = new GetCdps();
        user = new FakeUser();
    }

    function testOpenCDP() public {
        uint cdp = manager.open("ETH");
        assertEq(cdp, 1);
        assertEq(manager.lads(cdp), address(this));
    }

    function testOpenCDPOtherAddress() public {
        uint cdp = manager.open("ETH", address(123));
        assertEq(manager.lads(cdp), address(123));
    }

    function testTransferCDP() public {
        uint cdp = manager.open("ETH");
        manager.move(cdp, address(123));
        assertEq(manager.lads(cdp), address(123));
    }

    function testTransferAllowed() public {
        uint cdp = manager.open("ETH");
        manager.allow(cdp, address(user), true);
        user.doMove(manager, cdp, address(123));
        assertEq(manager.lads(cdp), address(123));
    }

    function testFailTransferNotAllowed() public {
        uint cdp = manager.open("ETH");
        user.doMove(manager, cdp, address(123));
    }

    function testFailTransferNotAllowed2() public {
        uint cdp = manager.open("ETH");
        manager.allow(cdp, address(user), true);
        manager.allow(cdp, address(user), false);
        user.doMove(manager, cdp, address(123));
    }

    function testFailTransferNotAllowed3() public {
        uint cdp = manager.open("ETH");
        uint cdp2 = manager.open("ETH");
        manager.allow(cdp2, address(user), true);
        user.doMove(manager, cdp, address(123));
    }

    function testFailTransferToSameOwner() public {
        uint cdp = manager.open("ETH");
        manager.move(cdp, address(this));
    }

    function testDoubleLinkedList() public {
        uint cdp1 = manager.open("ETH");
        uint cdp2 = manager.open("ETH");
        uint cdp3 = manager.open("ETH");

        uint cdp4 = manager.open("ETH", address(user));
        uint cdp5 = manager.open("ETH", address(user));
        uint cdp6 = manager.open("ETH", address(user));
        uint cdp7 = manager.open("ETH", address(user));

        assertEq(manager.count(address(this)), 3);
        assertTrue(manager.last(address(this)) == cdp3);
        (uint prev, uint next) = manager.cdps(cdp1);
        assertTrue(prev == 0);
        assertTrue(next == cdp2);
        (prev, next) = manager.cdps(cdp2);
        assertTrue(prev == cdp1);
        assertTrue(next == cdp3);
        (prev, next) = manager.cdps(cdp3);
        assertTrue(prev == cdp2);
        assertTrue(next == 0);

        assertEq(manager.count(address(user)), 4);
        assertTrue(manager.last(address(user)) == cdp7);
        (prev, next) = manager.cdps(cdp4);
        assertTrue(prev == 0);
        assertTrue(next == cdp5);
        (prev, next) = manager.cdps(cdp5);
        assertTrue(prev == cdp4);
        assertTrue(next == cdp6);
        (prev, next) = manager.cdps(cdp6);
        assertTrue(prev == cdp5);
        assertTrue(next == cdp7);
        (prev, next) = manager.cdps(cdp7);
        assertTrue(prev == cdp6);
        assertTrue(next == 0);

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
        assertTrue(next == 0);

        user.doMove(manager, cdp2, address(this));

        assertEq(manager.count(address(this)), 3);
        assertTrue(manager.last(address(this)) == cdp2);
        (prev, next) = manager.cdps(cdp3);
        assertTrue(next == cdp2);
        (prev, next) = manager.cdps(cdp2);
        assertTrue(prev == cdp3);
        assertTrue(next == 0);

        assertEq(manager.count(address(user)), 4);
        assertTrue(manager.last(address(user)) == cdp7);
        (prev, next) = manager.cdps(cdp7);
        assertTrue(next == 0);
    }

    function testGetCdps() public {
        uint cdp1 = manager.open("ETH");
        uint cdp2 = manager.open("REP");
        uint cdp3 = manager.open("GOLD");

        (uint[] memory cdps, bytes32[] memory ilks) = getCdps.getCdps(address(manager), address(this));
        assertEq(cdps.length, 3);
        assertEq(cdps[0], cdp3);
        assertTrue(ilks[0] == bytes32("GOLD"));
        assertEq(cdps[1], cdp2);
        assertTrue(ilks[1] == bytes32("REP"));
        assertEq(cdps[2], cdp1);
        assertTrue(ilks[2] == bytes32("ETH"));

        manager.move(cdp2, address(user));
        (cdps, ilks) = getCdps.getCdps(address(manager), address(this));
        assertEq(cdps.length, 2);
        assertEq(cdps[0], cdp3);
        assertTrue(ilks[0] == bytes32("GOLD"));
        assertEq(cdps[1], cdp1);
        assertTrue(ilks[1] == bytes32("ETH"));
    }

    function testFrob() public {
        deploy();
        uint cdp = manager.open("ETH");
        weth.deposit.value(1 ether)();
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.getUrn(cdp), 1 ether);
        manager.frob(address(vat), cdp, 1 ether, 50 ether);
        assertEq(vat.dai(manager.getUrn(cdp)), 50 ether * ONE);
        assertEq(dai.balanceOf(address(this)), 0);
        manager.exit(address(daiJoin), cdp, address(this), 50 ether);
        assertEq(dai.balanceOf(address(this)), 50 ether);
    }

    function testFrobAllowed() public {
        deploy();
        uint cdp = manager.open("ETH");
        weth.deposit.value(1 ether)();
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.getUrn(cdp), 1 ether);
        manager.allow(cdp, address(user), true);
        user.doFrob(manager, address(vat), cdp, 1 ether, 50 ether);
        assertEq(vat.dai(manager.getUrn(cdp)), 50 ether * ONE);
    }

    function testFailFrobNotAllowed() public {
        deploy();
        uint cdp = manager.open("ETH");
        weth.deposit.value(1 ether)();
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.getUrn(cdp), 1 ether);
        user.doFrob(manager, address(vat), cdp, 1 ether, 50 ether);
    }

    function testFrobGetCollateralBack() public {
        deploy();
        uint cdp = manager.open("ETH");
        weth.deposit.value(1 ether)();
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.getUrn(cdp), 1 ether);
        manager.frob(address(vat), cdp, 1 ether, 50 ether);
        manager.frob(address(vat), cdp, -int(1 ether), -int(50 ether));
        assertEq(vat.dai(manager.getUrn(cdp)), 0);
        assertEq(vat.gem("ETH", manager.getUrn(cdp)), 1 ether);
        uint prevBalance = address(this).balance;
        manager.exit(address(ethJoin), cdp, address(this), 1 ether);
        weth.withdraw(1 ether);
        assertEq(address(this).balance, prevBalance + 1 ether);
    }

    function testQuit() public {
        deploy();
        uint cdp = manager.open("ETH");
        weth.deposit.value(1 ether)();
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.getUrn(cdp), 1 ether);

        manager.frob(address(vat), cdp, 1 ether, 50 ether);
        (uint ink, uint art) = vat.urns("ETH", manager.getUrn(cdp));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);
        (ink, art) = vat.urns("ETH", urn);
        assertEq(ink, 0);
        assertEq(art, 0);

        vat.hope(address(manager));
        manager.quit(address(vat), cdp, urn);
        (ink, art) = vat.urns("ETH", manager.getUrn(cdp));
        assertEq(ink, 0);
        assertEq(art, 0);
        (ink, art) = vat.urns("ETH", urn);
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);
    }
}
