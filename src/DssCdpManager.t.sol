pragma solidity >= 0.5.0;

import { DssDeployTest } from "dss-deploy/DssDeploy.t.sol";
import "./DssCdpManager.sol";

contract FakeUser {
    function doMove(
        DssCdpManager manager,
        bytes32 ilk,
        bytes12 cdp,
        address dst
    ) public {
        manager.move(ilk, cdp, dst);
    }

    function doFrob(
        DssCdpManager manager,
        address pit,
        address daiMove,
        address gemMove,
        bytes32 ilk,
        bytes12 cdp,
        int dink,
        int dart,
        bytes32 dst
    ) public {
        manager.frob(pit, daiMove, gemMove, ilk, cdp, dink, dart, dst);
    }
}

contract DssCdpManagerTest is DssDeployTest {
    DssCdpManager manager;
    FakeUser user;

    function setUp() public {
        super.setUp();
        manager = new DssCdpManager();
        user = new FakeUser();
    }

    function _getUrn(bytes12 cdp) internal returns (bytes32 urn) {
        bytes20 addr = bytes20(address(manager));
        assembly {
            let p := mload(0x40)
            mstore(p, addr)
            mstore(add(p, 0x14), cdp)
            urn := mload(p)
        }
    }

    function testManagerOpenCDP() public {
        bytes12 cdp = manager.open("ETH");
        assertEq(bytes32(cdp), bytes32(bytes12(uint96(1))));
        assertEq(manager.cdps("ETH", cdp), address(this));
    }

    function testManagerOpenCDPOtherAddress() public {
        bytes12 cdp = manager.open("ETH", address(123));
        assertEq(manager.cdps("ETH", cdp), address(123));
    }

    function testManagerTransferCDP() public {
        bytes12 cdp = manager.open("ETH");
        manager.move("ETH", cdp, address(123));
        assertEq(manager.cdps("ETH", cdp), address(123));
    }

    function testManagerTransferAllowed() public {
        bytes12 cdp = manager.open("ETH");
        manager.allow(address(user), true);
        user.doMove(manager, "ETH", cdp, address(123));
        assertEq(manager.cdps("ETH", cdp), address(123));
    }

    function testFailManagerTransferNotAllowed() public {
        bytes12 cdp = manager.open("ETH");
        user.doMove(manager, "ETH", cdp, address(123));
    }

    function testFailManagerTransferNotAllowed2() public {
        bytes12 cdp = manager.open("ETH");
        manager.allow(address(user), true);
        manager.allow(address(user), false);
        user.doMove(manager, "ETH", cdp, address(123));
    }

    function testManagerFrob() public {
        deploy();
        bytes12 cdp = manager.open("ETH");
        ethJoin.join.value(1 ether)(manager.getUrn(cdp));
        manager.frob(address(pit), address(daiMove), address(ethMove), "ETH", cdp, 1 ether, 50 ether, bytes32(bytes20(address(this))));
        assertEq(vat.dai(bytes32(bytes20(address(this)))), 50 ether * ONE);
    }

    function testManagerFrobAllowed() public {
        deploy();
        bytes12 cdp = manager.open("ETH");
        ethJoin.join.value(1 ether)(manager.getUrn(cdp));
        manager.allow(address(user), true);
        user.doFrob(manager, address(pit), address(daiMove), address(ethMove), "ETH", cdp, 1 ether, 50 ether, bytes32(bytes20(address(this))));
        assertEq(vat.dai(bytes32(bytes20(address(this)))), 50 ether * ONE);
    }

    function testFailManagerFrobNotAllowed() public {
        deploy();
        bytes12 cdp = manager.open("ETH");
        ethJoin.join.value(1 ether)(manager.getUrn(cdp));
        user.doFrob(manager, address(pit), address(daiMove), address(ethMove), "ETH", cdp, 1 ether, 50 ether, bytes32(bytes20(address(this))));
    }

    function testManagerFrobGetCollateralBack() public {
        deploy();
        bytes12 cdp = manager.open("ETH");
        ethJoin.join.value(1 ether)(manager.getUrn(cdp));
        manager.frob(address(pit), address(daiMove), address(ethMove), "ETH", cdp, 1 ether, 50 ether, manager.getUrn(cdp));
        manager.frob(address(pit), address(daiMove), address(ethMove), "ETH", cdp, -int(1 ether), -int(50 ether), bytes32(bytes20(address(this))));
        assertEq(vat.dai(bytes32(bytes20(address(this)))), 0);
        assertEq(vat.gem("ETH", bytes32(bytes20(address(this)))), 1 ether * ONE);
    }
}
