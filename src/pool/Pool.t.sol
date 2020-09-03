pragma solidity ^0.5.12;

import {BCdpManagerTestBase, Hevm, FakeUser} from "./../BCdpManager.t.sol";
import {BCdpScore} from "./../BCdpScore.sol";
import {Pool} from "./Pool.sol";
import {LiquidationMachine} from "./../LiquidationMachine.sol";


contract FakeMember is FakeUser {
    function doDeposit(Pool pool, uint rad) public {
        pool.deposit(rad);
    }

    function doWithdraw(Pool pool, uint rad) public {
        pool.withdraw(rad);
    }

    function doTopup(Pool pool, uint cdp) public {
        pool.topup(cdp);
    }

    function doUntop(Pool pool, uint cdp) public {
        pool.untop(cdp);
    }

    function doPoolBite(Pool pool, uint cdp, uint dart, uint minInk) public returns(uint){
        return pool.bite(cdp,dart,minInk);
    }
}

contract PoolTest is BCdpManagerTestBase {
    uint currTime;
    FakeMember member;
    FakeMember[] members;
    FakeMember nonMember;
    address constant JAR = address(0x1234567890);

    function setUp() public {
        super.setUp();

        currTime = now;
        hevm.warp(currTime);

        address[] memory memoryMembers = new address[](4);
        for(uint i = 0 ; i < 5 ; i++) {
            FakeMember m = new FakeMember();
            seedMember(m);
            m.doHope(vat,address(pool));

            if(i < 4) {
                members.push(m);
                memoryMembers[i] = address(m);
            }
            else nonMember = m;
        }

        pool.setMembers(memoryMembers);
        pool.setProfitParams(1,100);
        pool.setIlk("ETH",true);

        member = members[0];
    }

    function getMembers() internal view returns(address[] memory) {
        address[] memory memoryMembers = new address[](members.length);
        for(uint i = 0 ; i < members.length ; i++) {
            memoryMembers[i] = address(members[i]);
        }

        return memoryMembers;
    }

    function radToWei(uint rad) pure internal returns(uint) {
        return rad/RAY;
    }

    function openCdp(uint ink,uint art) internal returns(uint){
        uint cdp = manager.open("ETH", address(this));

        weth.mint(ink);
        weth.approve(address(ethJoin), ink);
        ethJoin.join(manager.urns(cdp), ink);

        manager.frob(cdp, int(ink), int(art));

        return cdp;
    }

    function seedMember(FakeMember m) internal {
        uint cdp = openCdp(1e3 ether, 1e3 ether);
        manager.move(cdp,address(m),1e3 ether * RAY);
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
        assertEq(RAY,duty);
        assertEq(uint(address(vat)),uint(address(jug.vat())));
        jug.drip("ETH");
        forwardTime(1);
        jug.drip("ETH");
        this.file(address(jug),"ETH","duty",RAY + RAY/10);
        (duty,) = jug.ilks("ETH");
        assertEq(RAY + RAY / 10,duty);
        forwardTime(1);
        jug.drip("ETH");
        (,rho) = jug.ilks("ETH");
        assertEq(rho,now);
        (,uint rate,,,) = vat.ilks("ETH");
        assertEq(RAY + RAY/10,rate);
    }

    function almostEqual(uint a, uint b) internal returns(bool) {
        assert(a < uint(1) << 200 && b < uint(1) << 200);

        if(a > b) return almostEqual(b,a);
        if(a * (1e6 + 1) < b * 1e6) return false;

        return true;
    }

    function assertAlmostEq(uint a, uint b) internal {
        if(a > b + 1) {
            assertEq(a,b);
            assertEq(uint(1),2);
        }
        if(b > a + 1) {
            assertEq(a,b);
            assertEq(uint(1),3);
        }
    }

    function testDeposit() public {
        uint userBalance = vat.dai(address(member));
        assertEq(pool.rad(address(member)), 0);
        member.doDeposit(pool,123);
        assertEq(pool.rad(address(member)), 123);
        assertEq(vat.dai(address(member)),userBalance - 123);
    }

    function testFailedDeposit() public {
        nonMember.doDeposit(pool,123);
    }

    function testWithdraw() public {
        uint userBalance = vat.dai(address(member));
        member.doDeposit(pool,123);
        member.doWithdraw(pool,112);
        assertEq(pool.rad(address(member)), 123 - 112);
        assertEq(vat.dai(address(member)),userBalance - 123 + 112);
    }

    function testFailedWithdrawNonMember() public {
        nonMember.doWithdraw(pool,1);
    }

    function testFailedWithdrawInsufficientFunds() public {
        member.doDeposit(pool,123);
        members[1].doDeposit(pool,123);
        member.doWithdraw(pool,123 + 1);
    }

    // 2 out of 4 are selected
    function testchooseMembers1() public {
        // sufficient
        members[0].doDeposit(pool,1000);
        members[2].doDeposit(pool,950);

        // insufficient
        members[1].doDeposit(pool,100);
        members[3].doDeposit(pool,95);

        address[] memory winners = pool.chooseMembers(404,getMembers());
        assertEq(winners.length, 2);
        assertEq(winners[0], address(members[0]));
        assertEq(winners[1], address(members[2]));
    }

    // 2 out of 4 are selected, third user has enough when divided by 4, but not by 3.
    function testchooseMembers2() public {
        // sufficient
        members[1].doDeposit(pool,1000);
        members[3].doDeposit(pool,950);

        // insufficient
        members[0].doDeposit(pool,110);
        members[2].doDeposit(pool,95);

        address[] memory winners = pool.chooseMembers(400,getMembers());
        assertEq(winners.length, 2);
        assertEq(winners[0], address(members[1]));
        assertEq(winners[1], address(members[3]));
    }

    // all are selected
    function testchooseMembers3() public {
        // sufficient
        members[0].doDeposit(pool,1000);
        members[1].doDeposit(pool,950);
        members[2].doDeposit(pool,850);
        members[3].doDeposit(pool,750);

        address[] memory winners = pool.chooseMembers(400,getMembers());
        assertEq(winners.length, 4);
        assertEq(winners[0], address(members[0]));
        assertEq(winners[1], address(members[1]));
        assertEq(winners[2], address(members[2]));
        assertEq(winners[3], address(members[3]));
    }

    // none are selected
    function testchooseMembers4() public {
        // insufficient
        members[0].doDeposit(pool,99);
        members[1].doDeposit(pool,399);
        members[2].doDeposit(pool,101);
        members[3].doDeposit(pool,199);

        address[] memory winners = pool.chooseMembers(400,getMembers());
        assertEq(winners.length, 0);
    }

    // test all possibilities
    function testchooseMembers5() public {
        uint rad = 1000;
        for(uint i = 0 ; i < 16 ; i++) {
            uint expectedNum = 0;
            if(i & 0x1 > 0) expectedNum++;
            if(i & 0x2 > 0) expectedNum++;
            if(i & 0x4 > 0) expectedNum++;
            if(i & 0x8 > 0) expectedNum++;

            address[] memory expectedWinners = new address[](expectedNum);
            uint assignedWinners = 0;

            for(uint j = 0 ; j < members.length ; j++) {
                members[j].doWithdraw(pool, pool.rad(address(members[j])));
                if((i >> j) & 0x1 > 0) {
                    members[j].doDeposit(pool,1 + rad/expectedNum);
                    expectedWinners[assignedWinners++] = address(members[j]);
                }
                else members[j].doDeposit(pool,rad/members.length - 1);
            }

            address[] memory winners = pool.chooseMembers(rad,getMembers());
            assertEq(winners.length, expectedNum);
            for(uint k = 0 ; k < winners.length ; k++) {
                assertEq(winners[k],expectedWinners[k]);
            }
        }
    }

    // todo test real functionallity
    function testSetIlk() public {
        pool.setIlk("ETH-A",true);
        assert(pool.ilks("ETH-A") == true);
        pool.setIlk("ETH-A",false);
        assert(pool.ilks("ETH-A") == false);

        pool.setIlk("ETH-B",false);
        pool.setIlk("ETH-C",true);
        pool.setIlk("ETH-D",false);
        pool.setIlk("ETH-E",true);

        assert(pool.ilks("ETH-B") == false);
        assert(pool.ilks("ETH-C") == true);
        assert(pool.ilks("ETH-D") == false);
        assert(pool.ilks("ETH-E") == true);
    }

    // TODO - test real functionallity
    function testSetProfitParams() public {
        pool.setProfitParams(123,456);
        assertEq(pool.shrn(),123);
        assertEq(pool.shrd(),456);
    }

    function testchooseMember1() public {
        // sufficient
        members[2].doDeposit(pool,1000);

        address[] memory winners = pool.chooseMember(0,404,getMembers());
        assertEq(winners.length, 1);
        assertEq(winners[0], address(members[2]));
    }

    function testchooseMember2() public {
        // sufficient
        members[0].doDeposit(pool,1000);
        members[1].doDeposit(pool,1000);
        members[2].doDeposit(pool,1000);
        members[3].doDeposit(pool,1000);

        bool one = true; bool two = true; bool three = true; bool four = true;
        uint maxNumIter = 1000;

        timeReset();
        while(one || two || three || four) {
            assert(maxNumIter-- > 0);

            address[] memory winners = pool.chooseMember(0,404,getMembers());
            assertEq(winners.length, 1);
            if(winners[0] == address(members[0])) one = false;
            if(winners[0] == address(members[1])) two = false;
            if(winners[0] == address(members[2])) three = false;
            if(winners[0] == address(members[3])) four = false;

            forwardTime(23 minutes);
        }
    }

    function testTopAmount() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        timeReset();
        osm.setH(60 * 60);
        osm.setZ(currTime - 40*60);

        (int dart, int dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab),10 ether * RAY);
        assertEq(art,110 ether);
        assertEq(uint(dart) * RAY,uint(dtab));
    }

    function testTopAmountWithRate() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 100 ether); // 1 eth, 100 dai

        // debt increased to 110 dai
        setRateTo1p1();

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        timeReset();
        osm.setH(60 * 60);
        osm.setZ(currTime - 40*60);

        (int dart, int dtab, uint art) = pool.topAmount(cdp);

        assert(almostEqual(uint(dtab),10 ether * RAY));
        assertEq(art,100 ether);
        assert(almostEqual(uint(dart),10 ether * uint(100) / 110));
    }

    function testTopAmountNoCushion() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 90 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of -10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        timeReset();
        osm.setH(60 * 60);
        osm.setZ(currTime - 40*60);

        (int dart, int dtab, uint art) = pool.topAmount(cdp);

        assertEq(dtab,-10 ether * int(RAY));
        assertEq(art,90 ether);
        assertEq(dart * int(RAY),dtab);
    }

    function testTopAmountTooEarly() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 90 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of -10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        osm.setH(60 * 60);
        osm.setZ(currTime - 10*60);

        (int dart, int dtab, uint art) = pool.topAmount(cdp);

        assertEq(dtab,0);
        assertEq(art,90 ether);
        assertEq(dart,0);
    }

    function testTopAmountInvalidIlk() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 90 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of -10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        pool.setIlk("ETH",false);

        (int dart, int dtab, uint art) = pool.topAmount(cdp);

        assertEq(dtab,0);
        assertEq(art,90 ether);
        assertEq(dart,0);
    }

    function testTopAmountInvalidOsmPrice() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 90 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of -10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        osm.setValid(false);

        (int dart, int dtab, uint art) = pool.topAmount(cdp);

        assertEq(dtab,0);
        assertEq(art,90 ether);
        assertEq(dart,0);
    }

    function testHappyTopup() public returns(uint cdp) {
        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);

        pool.setMinArt(1 ether);

        // open cdp with rate  = 1, that hit liquidation state
        cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (int dart, int dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab),10 ether * RAY);
        assertEq(art,110 ether);
        assertEq(uint(dart) * RAY,uint(dtab));

        members[0].doTopup(pool,cdp);

        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        assertEq(art,cdpArt);
        assertEq(cdpCushion,uint(dtab));
        assertEq(winners.length,4);
        assertEq(address(winners[0]),address(members[0]));
        assertEq(address(winners[1]),address(members[1]));
        assertEq(address(winners[2]),address(members[2]));
        assertEq(address(winners[3]),address(members[3]));

        // check balances
        assertEq(pool.rad(address(members[0])),uint(1000 ether * RAY) - uint(1+ dtab/4));
        assertEq(pool.rad(address(members[1])),uint(950 ether * RAY) - uint(1+ dtab/4));
        assertEq(pool.rad(address(members[2])),uint(900 ether * RAY) - uint(1+ dtab/4));
        assertEq(pool.rad(address(members[3])),uint(850 ether * RAY) - uint(1+ dtab/4));
    }

    function testSingleTopup() public {
        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);

        pool.setMinArt(10000 ether);

        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (int dart, int dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab),10 ether * RAY);
        assertEq(art,110 ether);
        assertEq(uint(dart) * RAY,uint(dtab));

        address[] memory singleMember = pool.chooseMember(cdp,uint(dtab),getMembers());

        FakeMember(singleMember[0]).doTopup(pool,cdp);

        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        assertEq(art,cdpArt);
        assertEq(cdpCushion,uint(dtab));
        assertEq(winners.length,1);
        assertEq(address(winners[0]),address(singleMember[0]));

        for(uint i = 0 ; i < 4 ; i++) {
            uint expectedRad = (1000 - 50 * i) * 1 ether * RAY;
            if(address(members[i]) == address(singleMember[0])) expectedRad -= (uint(dtab) + 1);

            assertEq(expectedRad,pool.rad(address(members[i])));
        }
    }

    function testFailedSingleTopupWrongMemberTopup() public {
        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);

        pool.setMinArt(10000 ether);

        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (int dart, int dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab),10 ether * RAY);
        assertEq(art,110 ether);
        assertEq(uint(dart) * RAY,uint(dtab));

        address[] memory singleMember = pool.chooseMember(cdp,uint(dtab),getMembers());

        if(address(singleMember[0]) == address(members[0])) members[1].doTopup(pool,cdp);
        else members[0].doTopup(pool,cdp);
    }

    function testFailedTopupCushionExist() public {
        uint cdp = testHappyTopup();
        members[0].doTopup(pool,cdp);
    }

    function testFailedTopupNoNeed() public {
        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);

        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        (int dart, int dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab),0);
        assertEq(art,110 ether);
        assertEq(uint(dart) * RAY,uint(dtab));

        members[0].doTopup(pool,cdp);
    }

    function testFailedTopupPoorMembers() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (int dart, int dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab),10 ether * RAY);
        assertEq(art,110 ether);
        assertEq(uint(dart) * RAY,uint(dtab));

        members[0].doTopup(pool,cdp);
    }

    function testUntopSingle() public {
        members[0].doDeposit(pool,1000 ether * RAY);

        pool.setMinArt(10000 ether);

        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (int dart, int dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab),10 ether * RAY);
        assertEq(art,110 ether);
        assertEq(uint(dart) * RAY,uint(dtab));

        members[0].doTopup(pool,cdp);

        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        assertEq(art,cdpArt);
        assertEq(cdpCushion,uint(dtab));
        assertEq(winners.length,1);
        assertEq(address(winners[0]),address(members[0]));

        assertEq(pool.rad(address(members[0])),1000 ether * RAY - uint(dtab) - 1);

        // do dummy frob, which will call topup
        manager.frob(cdp, -1, 0);

        // do untop
        members[0].doUntop(pool,cdp);

        (uint cdpArt2, uint cdpCushion2, address[] memory winners2, uint[] memory bite2) = pool.getCdpData(cdp);
        assertEq(0,cdpArt2);
        assertEq(cdpCushion2,0);
        assertEq(winners2.length,0);

        assertEq(pool.rad(address(members[0])),1000 ether * RAY - 1);
    }

    function testUntopHappy() public {
        uint cdp = testHappyTopup();

        // do dummy frob, which will call topup
        manager.frob(cdp, -1, 0);

        // do untop
        members[0].doUntop(pool,cdp);

        (uint cdpArt2, uint cdpCushion2, address[] memory winners2, uint[] memory bite2) = pool.getCdpData(cdp);
        assertEq(cdpArt2,0);
        assertEq(cdpCushion2,0);
        assertEq(winners2.length,0);

        assertEq(pool.rad(address(members[0])),1000 ether * RAY - 1);
        assertEq(pool.rad(address(members[1])),950 ether * RAY - 1);
        assertEq(pool.rad(address(members[2])),900 ether * RAY - 1);
        assertEq(pool.rad(address(members[3])),850 ether * RAY - 1);
    }

    function testFailedUntopCushionNotReleased() public {
        uint cdp = testHappyTopup();

        // do untop
        members[0].doUntop(pool,cdp);
    }

    function testSimpleBite() public {
        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);

        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        members[0].doTopup(pool,cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",130 * 1e18);

        uint ethBefore = vat.gem("ETH",address(members[0]));
        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(1,100); // 1% goes to jar
        // for 10 ether we expect 10/130 * 1.1 = 11/130, from which 99% goes to member
        uint expectedEth = uint(99) * 11 ether / (130 * 100);
        uint dink = members[0].doPoolBite(pool,cdp,10 ether,expectedEth);
        assertEq(uint(dink), expectedEth);
        assertEq(vat.gem("ETH",address(members[0])),expectedEth);
        assertEq(vat.gem("ETH",address(jar)),11 ether / uint(130 * 100));

        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        assertEq(bite[0],10 ether);

        uint userRemainingCushion = 1 + cdpCushion / 4 - 10 * cdpCushion / 110; // 10/110 of the debt is being bitten
        uint userPoolBalance = radToWei(pool.rad(address(members[0])));
        uint userExpectedPoolBalance = radToWei(990 ether * RAY - userRemainingCushion) - 1; // TODO - check why -1?
        assertEq(userPoolBalance,userExpectedPoolBalance);
    }

    function testFullBite() public {
        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        members[0].doTopup(pool,cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",130 * 1e18);

        uint ethBefore = vat.gem("ETH",address(members[0]));
        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(2,100); // 2% goes to jar
        // for 26 ether we expect 26/130 * 1.1 = 28.6/130, from which 98% goes to member
        uint expectedEth = uint(98) * 286 ether / (130 * 100 * 10);
        for(uint i = 0 ; i < 4 ; i++) {
            uint dink = members[i].doPoolBite(pool,cdp,26 ether,expectedEth);
            assertEq(uint(dink), expectedEth);
            assertEq(vat.gem("ETH",address(members[i])),expectedEth);
            (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
            assertEq(bite[i],26 ether);
            assertEq(pool.rad(address(members[i])),(1000 ether - 50 ether * i - 26 ether) * RAY - 1);
        }

        // jar should get 2% from 104 * 1.1 / 130
        assertEq(vat.gem("ETH",address(jar)),(104 ether * 11 / 1300)/50);
    }

    function doBite(FakeMember m, Pool pool, uint cdp, uint dart,bool rate) internal {
        (bytes32 price32) = realPrice.read("ETH");
        uint price = uint(price32);

        uint shrn = pool.shrn();
        uint shrd = pool.shrd();

        // 10% chop
        uint expectedJar = (dart * 1e18 * 110 / (price*100)) * shrn / shrd;
        uint expectedInk = (dart * 1e18 * 110 / (price*100)) - expectedJar;

        if(rate) {
            expectedJar = expectedJar * 11 / 10;
            expectedInk = expectedInk * 11 / 10;
        }

        uint mInkBefore = vat.gem("ETH",address(m));
        uint jarInkBefore = vat.gem("ETH",address(jar));

        m.doBite(pool,cdp,dart,expectedInk);

        uint mInkAfter = vat.gem("ETH",address(m));
        uint jarInkAfter = vat.gem("ETH",address(jar));

        assert(mInkAfter - mInkBefore <= expectedInk + 1 && expectedInk <= 1 + mInkAfter - mInkBefore);
        assert(jarInkAfter - jarInkBefore <= expectedJar + 1 && expectedJar <= 1 + jarInkAfter - jarInkBefore);
    }

    function testBiteInPartsThenUntop() public {
        timeReset();

        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        members[3].doTopup(pool,cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",130 * 1e18);

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(65,1000); // 6.5% goes to jar

        doBite(members[1], pool, cdp, 15 ether, false);
        doBite(members[0], pool, cdp, 13 ether, false);
        doBite(members[2], pool, cdp, 17 ether, false);
        doBite(members[1], pool, cdp, 9 ether, false);
        doBite(members[0], pool, cdp, 10 ether, false);
        doBite(members[0], pool, cdp, 3 ether, false);

        assert(LiquidationMachine(manager).bitten(cdp));

        // fast forward until no longer bitten
        forwardTime(60*60 + 1);
        assert(! LiquidationMachine(manager).bitten(cdp));

        // do dummy operation to untop
        manager.frob(cdp, -1, 0);

        members[3].doUntop(pool,cdp);

        // check balances
        // 0 consumed 26 ether
        assertEq(radToWei(pool.rad(address(members[0]))),radToWei((1000 ether - 26 ether) * RAY - 1)-1);
        // 1 consumed 24 ether
        assertEq(radToWei(pool.rad(address(members[1]))),radToWei((950 ether - 24 ether) * RAY - 1));
        // 2 consumed 17 ether
        assertEq(radToWei(pool.rad(address(members[2]))),radToWei((900 ether - 17 ether) * RAY - 1));
        // 3 consumed 0 ether
        assertEq(radToWei(pool.rad(address(members[3]))),radToWei((850 ether - 0 ether) * RAY - 1));

        // check that cdp was reset
        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        assertEq(cdpArt,0);
        assertEq(cdpCushion,0);
        assertEq(winners.length,0);
        assertEq(bite.length,0);
    }

    function testFailedBiteTooMuch() public {
        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(65,1000); // 6.5% goes to jar

        members[0].doTopup(pool,cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",130 * 1e18);

        members[0].doBite(pool,cdp,15 ether, 1);
        members[0].doBite(pool,cdp,11 ether + 1, 1);
    }

    function testFailedBiteInvalidMember() public {
        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,0 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(65,1000); // 6.5% goes to jar

        members[0].doTopup(pool,cdp);

        members[3].doDeposit(pool,850 ether * RAY);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",130 * 1e18);

        members[3].doBite(pool,cdp,15 ether, 1);
    }

    function testFailedBiteLowDink() public {
        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(65,1000); // 6.5% goes to jar

        members[0].doTopup(pool,cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",130 * 1e18);

        members[0].doBite(pool,cdp,15 ether, 1 ether);
    }

    function testBiteInPartsThenUntopNonOneRate() public {
        timeReset();

        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        setRateTo1p1(); // debt is 10% up

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        members[3].doTopup(pool,cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",149 * 1e18);

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(65,1000); // 6.5% goes to jar

        doBite(members[1], pool, cdp, 15 ether, true);
        doBite(members[0], pool, cdp, 13 ether, true);
        doBite(members[2], pool, cdp, 17 ether, true);
        doBite(members[1], pool, cdp, 9 ether, true);
        doBite(members[0], pool, cdp, 10 ether, true);
        doBite(members[0], pool, cdp, 3 ether, true);

        assert(LiquidationMachine(manager).bitten(cdp));

        // fast forward until no longer bitten
        forwardTime(60*60 + 1);
        assert(! LiquidationMachine(manager).bitten(cdp));

        // do dummy operation to untop
        manager.frob(cdp, -1, 0);

        members[3].doUntop(pool,cdp);

        // check balances
        // 0 consumed 26 ether
        assertEq(radToWei(pool.rad(address(members[0]))),radToWei((1000 ether - 26 ether * 11/10) * RAY - 1)-1);
        // 1 consumed 24 ether
        assertEq(radToWei(pool.rad(address(members[1]))),radToWei((950 ether - 24 ether * 11/10) * RAY - 1));
        // 2 consumed 17 ether
        assertEq(radToWei(pool.rad(address(members[2]))),radToWei((900 ether - 17 ether * 11/10) * RAY - 1));
        // 3 consumed 0 ether
        assertEq(radToWei(pool.rad(address(members[3]))),radToWei((850 ether - 0 ether * 11/10) * RAY - 1));

        // check that cdp was reset
        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        assertEq(cdpArt,0);
        assertEq(cdpCushion,0);
        assertEq(winners.length,0);
        assertEq(bite.length,0);
    }

    function testFullBiteWithRate() public {
        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        setRateTo1p1(); // debt is 10% up

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        members[0].doTopup(pool,cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",140 * 1e18);

        uint ethBefore = vat.gem("ETH",address(members[0]));
        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(2,100); // 2% goes to jar
        // for 26 ether we expect 26/140 * 1.1 * 1.1 = 28.6/140, from which 98% goes to member
        uint expectedEth = uint(98) * 286 ether * 11/ (140 * 100 * 10 * 10);
        for(uint i = 0 ; i < 4 ; i++) {
            uint dink = members[i].doPoolBite(pool,cdp,26 ether,expectedEth);
            assertEq(uint(dink), expectedEth);
            assertEq(vat.gem("ETH",address(members[i])),expectedEth);
            (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
            assertEq(bite[i],26 ether);
            assertAlmostEq(pool.rad(address(members[i]))/RAY,((1000 ether - 50 ether * i - 26 ether * uint(11)/10) * RAY - 1)/RAY);
        }

        // jar should get 2% from 104 * 1.1 * 1.1 / 140
        assertEq(vat.gem("ETH",address(jar)),(104 ether * uint(11) * 11/ 1400)/500 - 1);
    }

    function testAvailArtWithDust() public {
        timeReset();

        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);

        uint daiAmt = 104 ether + 111111111111111111; // 104.11 dai
        uint cdp = openCdp(1 ether, daiAmt); // 1 eth

        members[3].doTopup(pool,cdp);

        uint expectedAvailArt = daiAmt / members.length;
        uint expectedDust = daiAmt % members.length;
        assertEq(pool.availArt(cdp, address(members[0])), expectedAvailArt + expectedDust);
        assertEq(pool.availArt(cdp, address(members[1])), expectedAvailArt);
        assertEq(pool.availArt(cdp, address(members[2])), expectedAvailArt);
        assertEq(pool.availArt(cdp, address(members[3])), expectedAvailArt);

        assertEq(members.length * expectedAvailArt + expectedDust, daiAmt);
    }


    function testAvailArtWithoutDust() public {
        timeReset();

        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);

        uint daiAmt = 104 ether;
        uint cdp = openCdp(1 ether, daiAmt); // 1 eth, 104 dai

        members[3].doTopup(pool,cdp);

        uint expectedAvailArt = daiAmt / members.length;
        uint expectedDust = daiAmt % members.length;
        assertEq(expectedDust, 0);

        assertEq(pool.availArt(cdp, address(members[0])), expectedAvailArt);
        assertEq(pool.availArt(cdp, address(members[1])), expectedAvailArt);
        assertEq(pool.availArt(cdp, address(members[2])), expectedAvailArt);
        assertEq(pool.availArt(cdp, address(members[3])), expectedAvailArt);

        assertEq(members.length * expectedAvailArt, daiAmt);
    }


    function testFullBiteWithRateAndDust() public {
        members[0].doDeposit(pool,1000 ether * RAY);
        members[1].doDeposit(pool,950 ether * RAY);
        members[2].doDeposit(pool,900 ether * RAY);
        members[3].doDeposit(pool,850 ether * RAY);
        
        uint extraDust = 111111111111111111;
        uint _1p1 = WAD + WAD/10;
        uint daiAmt = 104 ether + extraDust; // 104.11 dai
        uint cdp = openCdp(1 ether, daiAmt); // 1 eth

        setRateTo1p1(); // debt is 10% up

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        members[0].doTopup(pool,cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        realPrice.set("ETH",140 * 1e18);

        uint ethBefore = vat.gem("ETH",address(members[0]));
        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(2,100); // 2% goes to jar

        uint expectedAvailArt = daiAmt / members.length;
        uint expectedDust = daiAmt % members.length;
        assertEq(expectedDust, 3);

        assertEq(pool.availArt(cdp, address(members[0])), expectedAvailArt + expectedDust);
        assertEq(pool.availArt(cdp, address(members[1])), expectedAvailArt);
        assertEq(pool.availArt(cdp, address(members[2])), expectedAvailArt);
        assertEq(pool.availArt(cdp, address(members[3])), expectedAvailArt);

        // for 26 ether we expect 26/140 * 1.1 = 28.6/140, from which 98% goes to member
        uint expectedEth = uint(98) * 286 ether * 11/ (140 * 100 * 10 * 10);
        uint amt = daiAmt / members.length;

        members[0].doPoolBite(pool,cdp,amt+expectedDust,expectedEth);
        members[1].doPoolBite(pool,cdp,amt,expectedEth);
        members[2].doPoolBite(pool,cdp,amt,expectedEth);
        members[3].doPoolBite(pool,cdp,amt,expectedEth);

        assertEq(pool.availArt(cdp, address(members[0])), 0);
        assertEq(pool.availArt(cdp, address(members[1])), 0);
        assertEq(pool.availArt(cdp, address(members[2])), 0);
        assertEq(pool.availArt(cdp, address(members[3])), 0);

        // jar should get 2% from 104 * 1.1 * 1.1 / 140
        almostEqual(vat.gem("ETH",address(jar)),(daiAmt * uint(11) * 11/ 1400)/500 - 1);
    }



    // tests to do

    // topup - during bite
    // untop - sad (during bite), untop after partial bite
}
