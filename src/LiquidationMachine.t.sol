pragma solidity ^0.5.12;

import {Vat, Jug} from "dss-deploy/DssDeploy.t.base.sol";
import {BCdpManagerTestBase, Hevm, FakeUser} from "./BCdpManager.t.sol_";
import {LiquidationMachine} from "./LiquidationMachine.sol";
import {BCdpManager} from "./BCdpManager.sol";

contract FakePool {
    function doTopup(LiquidationMachine lm, uint cdp, uint dtopup) public {
        lm.topup(cdp,dtopup);
    }

    function doUntopByPool(LiquidationMachine lm, uint cdp) public {
        lm.untopByPool(cdp);
    }

    function doBite(LiquidationMachine lm, uint cdp, uint dart) public {
        lm.bite(cdp,dart);
    }

    function doHope(Vat vat,address dst) public {
        vat.hope(dst);
    }
}

contract LiquidationMachineTest is BCdpManagerTestBase {
    uint currTime;

    LiquidationMachine lm;
    FakePool           fPool;

    function setUp() public {
        super.setUp();

        currTime = now;
        hevm.warp(currTime);

        fPool = new FakePool();
        manager = new BCdpManager(address(vat), address(cat), address(fPool), address(realPrice));
        fPool.doHope(vat,address(manager));
        lm = LiquidationMachine(manager);

        // put funds in pool
        uint cdp = openCdp(100 ether, 100 ether);
        manager.move(cdp,address(fPool),100 ether * ONE);
    }

    function timeReset() internal {
        currTime = now;
        hevm.warp(currTime);
    }

    function forwardTime(uint deltaInSec) internal {
        currTime += deltaInSec;
        hevm.warp(currTime);
    }

    function setRateTo1p1() internal {
        uint duty;
        uint rho;
        (duty,) = jug.ilks("ETH");
        assertEq(ONE,duty);
        assertEq(uint(address(vat)),uint(address(jug.vat())));
        jug.drip("ETH");
        forwardTime(1);
        jug.drip("ETH");
        this.file(address(jug),"ETH","duty",ONE + ONE/10);
        (duty,) = jug.ilks("ETH");
        assertEq(ONE + ONE / 10,duty);
        forwardTime(1);
        jug.drip("ETH");
        (,rho) = jug.ilks("ETH");
        assertEq(rho,now);
        (,uint rate,,,) = vat.ilks("ETH");
        assertEq(ONE + ONE/10,rate);
    }


    function openCdp(uint ink,uint art) internal returns(uint){
        uint cdp = manager.open("ETH", address(this));

        weth.deposit.value(ink)();
        weth.approve(address(ethJoin), ink);
        ethJoin.join(manager.urns(cdp), ink);

        manager.frob(cdp, int(ink), int(art));

        return cdp;
    }

    // topup from pool
    function testTopup() public {
        uint cdp = openCdp(50 ether, 50 ether);

        fPool.doTopup(lm,cdp,10 ether);

        address urn = manager.urns(cdp);
        (,uint art) = vat.urns("ETH", urn);

        assertEq(art,40 ether);
        assertEq(lm.cushion(cdp),10 ether);
        assertEq(vat.dai(address(fPool)),90 ether * ONE);
    }

    // topup not from pool
    function testFailedTopupFromNonPool() public {
        FakePool fPool2 = new FakePool();
        fPool2.doHope(vat,address(manager));
        uint cdp = openCdp(100 ether, 100 ether);
        manager.move(cdp,address(fPool),100 ether * ONE);

        fPool2.doTopup(lm,cdp,10 ether);
    }

    // happy path
    function testUntop() public {
        // first topup
        uint cdp = openCdp(50 ether, 50 ether);

        fPool.doTopup(lm,cdp,10 ether);
        address urn = manager.urns(cdp);
        (,uint art) = vat.urns("ETH", urn);

        assertEq(art,40 ether);
        assertEq(lm.cushion(cdp),10 ether);
        assertEq(vat.dai(address(fPool)),90 ether * ONE);

        // now untop
        fPool.doUntopByPool(lm,cdp);
        (,art) = vat.urns("ETH", urn);
        assertEq(art,50 ether);
        assertEq(lm.cushion(cdp),0 ether);
        assertEq(vat.dai(address(fPool)),100 ether * ONE);
    }

    // untop not from pool
    function testFailedUntopNotFromPool() public {
        // first topup
        uint cdp = openCdp(50 ether, 50 ether);

        fPool.doTopup(lm,cdp,10 ether);
        address urn = manager.urns(cdp);
        (,uint art) = vat.urns("ETH", urn);

        assertEq(art,40 ether);
        assertEq(lm.cushion(cdp),10 ether);
        assertEq(vat.dai(address(fPool)),90 ether * ONE);

        // now untop not from pool
        lm.untopByPool(cdp);
    }

    // untop failed in bite
    function testFailedUntopWhenBite() public {
        uint cdp = openCdp(1 ether, 50 ether);
        fPool.doTopup(lm,cdp,10 ether);

        // reach bite state
        osm.setPrice(70 * 1e18); // 1 ETH = 50 DAI
        pipETH.poke(bytes32(uint(70 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",70 * 1e18);

        fPool.doBite(lm,cdp,15 ether);
        assert(lm.bitten(cdp));

        fPool.doUntopByPool(lm,cdp);
    }

    // untop when cushion is 0
    function testUntopCushionZero() public {
        uint cdp = openCdp(50 ether, 50 ether);
        fPool.doUntopByPool(lm,cdp);

        address urn = manager.urns(cdp);
        (,uint art) = vat.urns("ETH", urn);

        assertEq(art,50 ether);
        assertEq(lm.cushion(cdp),0 ether);
        assertEq(vat.dai(address(fPool)),100 ether * ONE);
    }

    // top when rate is non one
    function testTopupAndUntopWithRate() public {
        setRateTo1p1();
        uint cdp = openCdp(50 ether, 50 ether);
        fPool.doTopup(lm,cdp,10 ether);

        address urn = manager.urns(cdp);
        (,uint art) = vat.urns("ETH", urn);
        assertEq(art,40 ether);
        assertEq(vat.dai(address(fPool)),(100 - 11) * 1 ether * ONE);

        fPool.doUntopByPool(lm,cdp);
        (,art) = vat.urns("ETH", urn);
        assertEq(art,50 ether);
        assertEq(vat.dai(address(fPool)),100 ether * ONE);
    }

    // top when rate is non one
    function testTopupAndUntopWithAccumulatedInterest() public {
        setRateTo1p1();
        uint cdp = openCdp(50 ether, 50 ether);
        fPool.doTopup(lm,cdp,10 ether);

        address urn = manager.urns(cdp);
        (,uint art) = vat.urns("ETH", urn);
        assertEq(art,40 ether);
        assertEq(vat.dai(address(fPool)),(100 - 11) * 1 ether * ONE);

        forwardTime(1);
        jug.drip("ETH");

        fPool.doUntopByPool(lm,cdp);
        (,art) = vat.urns("ETH", urn);
        assertEq(art,50 ether);
        // 10% interest per second
        assertEq(vat.dai(address(fPool)),100 ether * ONE + 11 ether * ONE / 10);
    }

    // TODO - test bite
}
