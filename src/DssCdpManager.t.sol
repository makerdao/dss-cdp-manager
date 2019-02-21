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
        assertEq(manager.cdps(cdp), address(this));
    }

    function testOpenCDPOtherAddress() public {
        bytes12 cdp = manager.open(address(123));
        assertEq(manager.cdps(cdp), address(123));
    }

    function testTransferCDP() public {
        bytes12 cdp = manager.open();
        manager.move(cdp, address(123));
        assertEq(manager.cdps(cdp), address(123));
    }

    function testTransferAllowed() public {
        bytes12 cdp = manager.open();
        manager.allow(cdp, address(user), true);
        user.doMove(manager, cdp, address(123));
        assertEq(manager.cdps(cdp), address(123));
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

    function testFrob() public {
        deploy();
        bytes12 cdp = manager.open();
        weth.deposit.value(1 ether)();
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.getUrn(cdp), 1 ether);
        manager.frob(address(pit), cdp, "ETH", 1 ether, 50 ether);
        assertEq(vat.dai(manager.getUrn(cdp)), 50 ether * ONE);
        assertEq(dai.balanceOf(address(this)), 0);
        manager.exit(address(daiJoin), cdp, address(this), 50 ether);
        assertEq(dai.balanceOf(address(this)), 50 ether);
    }

    function testFrobAllowed() public {
        deploy();
        bytes12 cdp = manager.open();
        weth.deposit.value(1 ether)();
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.getUrn(cdp), 1 ether);
        manager.allow(cdp, address(user), true);
        user.doFrob(manager, address(pit), cdp, "ETH", 1 ether, 50 ether);
        assertEq(vat.dai(manager.getUrn(cdp)), 50 ether * ONE);
    }

    function testFailFrobNotAllowed() public {
        deploy();
        bytes12 cdp = manager.open();
        weth.deposit.value(1 ether)();
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.getUrn(cdp), 1 ether);
        user.doFrob(manager, address(pit), cdp, "ETH", 1 ether, 50 ether);
    }

    function testFrobGetCollateralBack() public {
        deploy();
        bytes12 cdp = manager.open();
        weth.deposit.value(1 ether)();
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.getUrn(cdp), 1 ether);
        manager.frob(address(pit), cdp, "ETH", 1 ether, 50 ether);
        manager.frob(address(pit), cdp, "ETH", -int(1 ether), -int(50 ether));
        assertEq(vat.dai(manager.getUrn(cdp)), 0);
        assertEq(vat.gem("ETH", manager.getUrn(cdp)), 1 ether * ONE);
        uint prevBalance = address(this).balance;
        manager.exit(address(ethJoin), cdp, address(this), 1 ether);
        weth.withdraw(1 ether);
        assertEq(address(this).balance, prevBalance + 1 ether);
    }
}
