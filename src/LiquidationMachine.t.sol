pragma solidity ^0.5.12;

import {Vat, Jug} from "dss-deploy/DssDeploy.t.base.sol";
import {BCdpManagerTestBase, Hevm, FakeUser} from "./BCdpManager.t.sol";
import {LiquidationMachine} from "./LiquidationMachine.sol";
import {BCdpScore} from "./BCdpScore.sol";
import {BCdpManager} from "./BCdpManager.sol";

contract FakePool {
    function doTopup(LiquidationMachine lm, uint cdp, uint dtopup) public {
        lm.topup(cdp,dtopup);
    }

    function doUntopByPool(LiquidationMachine lm, uint cdp) public {
        lm.untopByPool(cdp);
    }

    function doBite(LiquidationMachine lm, uint cdp, uint dart) public returns(uint){
        return lm.bite(cdp,dart);
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
        BCdpScore score = new BCdpScore();
        manager = new BCdpManager(address(vat), address(end), address(fPool), address(realPrice),address(score));
        score.setManager(address(manager));
        fPool.doHope(vat,address(manager));
        lm = LiquidationMachine(manager);

        // put funds in pool
        uint cdp = openCdp(100 ether, 100 ether);
        manager.move(cdp,address(fPool),100 ether * ONE);

        this.file(address(cat), "ETH", "chop", 1130000000000000000000000000);
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

    // test bite, happy path
    function testBite() public {
        uint cdp = openCdp(1 ether, 50 ether);
        fPool.doTopup(lm,cdp,10 ether);

        // reach bite state
        osm.setPrice(70 * 1e18); // 1 ETH = 70 DAI
        pipETH.poke(bytes32(uint(70 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",70 * 1e18);

        uint daiBefore = vat.dai(address(fPool));
        uint dink = fPool.doBite(lm,cdp,10 ether);
        assert(lm.bitten(cdp));
        uint daiAfter = vat.dai(address(fPool));

        assertEq(dink,(10 ether * 113 / 100)/uint(70));
        // consumes 1/5 of the cushion
        assertEq(daiBefore - daiAfter, (10 ether - 2 ether)* ONE);
        assertEq(vat.gem("ETH",address(fPool)), dink);
    }

    // test bite, liquidate in one shot
    function testBiteAll() public {
        uint cdp = openCdp(1 ether, 50 ether);
        fPool.doTopup(lm,cdp,10 ether);

        // reach bite state
        osm.setPrice(70 * 1e18); // 1 ETH = 70 DAI
        pipETH.poke(bytes32(uint(70 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",70 * 1e18);

        uint daiBefore = vat.dai(address(fPool));
        uint dink = fPool.doBite(lm,cdp,50 ether);
        assert(lm.bitten(cdp));
        uint daiAfter = vat.dai(address(fPool));

        assertEq(dink,(50 ether * 113 / 100)/uint(70));
        // 10 ETH were reused from the cushion
        assertEq(daiBefore - daiAfter, (50 ether - 10 ether) * ONE);
        assertEq(vat.gem("ETH",address(fPool)), dink);
    }

    // test bite, liquidate in three steps
    function testBiteIn3Steps() public {
        uint cdp = openCdp(1 ether, 50 ether);
        fPool.doTopup(lm,cdp,10 ether);

        // reach bite state
        osm.setPrice(70 * 1e18); // 1 ETH = 70 DAI
        pipETH.poke(bytes32(uint(70 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",70 * 1e18);

        // bite 10,15,25
        uint daiBefore; uint dink; uint daiAfter;
        uint expectedBalance = 0;

        // bite 10
        daiBefore = vat.dai(address(fPool));
        dink = fPool.doBite(lm,cdp,10 ether);
        expectedBalance += dink;
        assert(lm.bitten(cdp));
        daiAfter = vat.dai(address(fPool));
        assertEq(dink,(10 ether * 113 / 100)/uint(70));
        // 10/5 ETH were reused from the cushion
        assertEq(daiBefore - daiAfter, (10 ether - 2 ether) * ONE);
        assertEq(vat.gem("ETH",address(fPool)), expectedBalance);

        // bite 15
        daiBefore = vat.dai(address(fPool));
        dink = fPool.doBite(lm,cdp,15 ether);
        expectedBalance += dink;
        assert(lm.bitten(cdp));
        daiAfter = vat.dai(address(fPool));
        assertEq(dink,(15 ether * 113 / 100)/uint(70));
        // 10 * 15/50 ETH were reused from the cushion
        assertEq(daiBefore - daiAfter, (15 ether - 10 ether * 15 / 50) * ONE);
        assertEq(vat.gem("ETH",address(fPool)), expectedBalance);

        // bite 25
        daiBefore = vat.dai(address(fPool));
        dink = fPool.doBite(lm,cdp,25 ether);
        expectedBalance += dink;
        assert(lm.bitten(cdp));
        daiAfter = vat.dai(address(fPool));
        assertEq(dink,(25 ether * 113 / 100)/uint(70));
        // 10 * 25/50 ETH were reused from the cushion
        assertEq(daiBefore - daiAfter, (25 ether - 10 ether * 25 / 50) * ONE);
        assertEq(vat.gem("ETH",address(fPool)), expectedBalance);
    }

    function testBiteAfterPriceBounces() public {
        uint cdp = openCdp(1 ether, 50 ether);
        fPool.doTopup(lm,cdp,10 ether);

        // reach bite state
        osm.setPrice(70 * 1e18); // 1 ETH = 70 DAI
        pipETH.poke(bytes32(uint(70 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",70 * 1e18);

        // bite 10,15
        uint daiBefore; uint dink; uint daiAfter;
        uint expectedBalance = 0;

        // bite 10
        daiBefore = vat.dai(address(fPool));
        dink = fPool.doBite(lm,cdp,10 ether);
        expectedBalance += dink;
        assert(lm.bitten(cdp));
        daiAfter = vat.dai(address(fPool));
        assertEq(dink,(10 ether * 113 / 100)/uint(70));
        // 10/5 ETH were reused from the cushion
        assertEq(daiBefore - daiAfter, (10 ether - 2 ether) * ONE);
        assertEq(vat.gem("ETH",address(fPool)), expectedBalance);

        // reach bite state
        osm.setPrice(700 * 1e18); // 1 ETH = 700 DAI
        pipETH.poke(bytes32(uint(700 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",700 * 1e18);

        // bite 15
        daiBefore = vat.dai(address(fPool));
        dink = fPool.doBite(lm,cdp,15 ether);
        expectedBalance += dink;
        assert(lm.bitten(cdp));
        daiAfter = vat.dai(address(fPool));
        assertEq(dink,(15 ether * 113 / 100)/uint(700));
        // 10 * 15/50 ETH were reused from the cushion
        assertEq(daiBefore - daiAfter, (15 ether - 10 ether * 15 / 50) * ONE);
        assertEq(vat.gem("ETH",address(fPool)), expectedBalance);
    }

    // test when rate is not 0
    function testBiteWithNonOneRate() public {
        setRateTo1p1();

        uint cdp = openCdp(1 ether, 50 ether);
        fPool.doTopup(lm,cdp,10 ether);

        // reach bite state
        osm.setPrice(70 * 1e18); // 1 ETH = 70 DAI
        pipETH.poke(bytes32(uint(70 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",70 * 1e18);

        // bite 10,15
        uint daiBefore; uint dink; uint daiAfter;
        uint expectedBalance = 0;

        // bite 10
        daiBefore = vat.dai(address(fPool));
        dink = fPool.doBite(lm,cdp,10 ether);
        expectedBalance += dink;
        assert(lm.bitten(cdp));
        daiAfter = vat.dai(address(fPool));
        uint estimatedInk = 110 * ( (10 ether * 113 / 100)/uint(70) ) / 100;
        assert(dink >= estimatedInk);
        assert(dink <= estimatedInk + 1);
        // 10/5 ETH were reused from the cushion
        assertEq(daiBefore - daiAfter, (10 ether - 2 ether) * 110 * ONE/100);
        assertEq(vat.gem("ETH",address(fPool)), expectedBalance);
    }

    // test bite sad paths
    function testFailedBiteWhenSafe() public {
        uint cdp = openCdp(1 ether, 50 ether);
        fPool.doTopup(lm,cdp,10 ether);

        fPool.doBite(lm,cdp,10 ether);
    }

    function testFailedHighDart() public {
        uint cdp = openCdp(1 ether, 50 ether);
        fPool.doTopup(lm,cdp,10 ether);

        // reach bite state
        osm.setPrice(70 * 1e18); // 1 ETH = 70 DAI
        pipETH.poke(bytes32(uint(70 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",70 * 1e18);

        fPool.doBite(lm,cdp,50 ether + 1);
    }

    function testFailedBiteAfterGrace() public {
        timeReset();

        uint cdp = openCdp(1 ether, 50 ether + 1);
        fPool.doTopup(lm,cdp,10 ether);

        // reach bite state
        osm.setPrice(75 * 1e18); // 1 ETH = 75 DAI
        pipETH.poke(bytes32(uint(75 * 1e18)));


        spotter.poke("ETH");
        realPrice.set("ETH",75 * 1e18);

        address urn = manager.urns(cdp);
        bytes32 ilk = manager.ilks(cdp);

        (uint ink, uint art) = vat.urns(ilk,urn);
        (,uint rate,uint spotValue,,) = vat.ilks(ilk);
        if(ink*spotValue > rate*(art+lm.cushion(cdp))) return; // prevent test from failing
        fPool.doBite(lm,cdp,10 ether);
        (ink, art) = vat.urns(ilk,urn);
        (,rate,spotValue,,) = vat.ilks(ilk);
        if(ink*spotValue < rate*(art+lm.cushion(cdp))) return; // prevent test from failing

        forwardTime(lm.GRACE()+1);

        // prevent test from failing
        if(lm.bitten(cdp)) return;

        // this should fail
        fPool.doBite(lm,cdp,10 ether);

    }

    // test bitten function
    function testBitten() public {
        timeReset();

        uint cdp = openCdp(1 ether, 50 ether);
        fPool.doTopup(lm,cdp,10 ether);

        // reach bite state
        osm.setPrice(70 * 1e18); // 1 ETH = 70 DAI
        pipETH.poke(bytes32(uint(70 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",70 * 1e18);

        assert(! lm.bitten(cdp));

        fPool.doBite(lm,cdp,10 ether);

        assert(lm.bitten(cdp));
        forwardTime(lm.GRACE() / 2);
        assert(lm.bitten(cdp));
        forwardTime(lm.GRACE() / 2 - 1);
        assert(lm.bitten(cdp));
        forwardTime(1);
        assert(! lm.bitten(cdp));
        forwardTime(1000);
        assert(! lm.bitten(cdp));
    }
}
