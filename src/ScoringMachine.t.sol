pragma solidity ^0.5.12;

import {BCdpManagerTestBase, Hevm, FakeUser} from "./BCdpManager.t.sol_";
import {BCdpScore} from "./BCdpScore.sol";

contract FakeSlasher {
    function doSlash(BCdpScore score, uint cdp, bytes32 ilk, int dart, uint time) public {
        score.slashScore(cdp,ilk,dart,time);
    }
}

contract ScordingMachineTest is BCdpManagerTestBase {
    uint currTime;

    BCdpScore score;

    function setUp() public {
        super.setUp();

        currTime = now;
        hevm.warp(currTime);

        score = BCdpScore(manager);
    }

    function openCdp(uint ink,uint art) internal returns(uint){
        uint cdp = manager.open("ETH", address(this));

        weth.deposit.value(ink)();
        weth.approve(address(ethJoin), ink);
        ethJoin.join(manager.urns(cdp), ink);

        manager.frob(cdp, int(ink), int(art));

        return cdp;
    }

    function timeReset() internal {
        currTime = now;
        hevm.warp(currTime);
    }

    function forwardTime(uint deltaInSec) internal {
        currTime += deltaInSec;
        hevm.warp(currTime);
    }

    function testOpenCdp() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp = openCdp(0 ether,0 ether);
        forwardTime(10);

        assertEq(score.getInkScore(cdp,"ETH",currTime,score.start()), 0);
        assertEq(score.getInkGlobalScore("ETH",currTime,score.start()), 0);

        assertEq(score.getArtScore(cdp,"ETH",currTime,score.start()), 0);
        assertEq(score.getArtGlobalScore("ETH",currTime,score.start()), 0);
    }

    function testShiftCdp() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp = openCdp(1 ether,1 ether);
        forwardTime(10);
        manager.give(cdp, address(123));
        assertEq(manager.owns(cdp), address(123));
        forwardTime(10);

        assertEq(score.getInkScore(cdp,"ETH",currTime,score.start()), 20 ether);
        assertEq(score.getInkGlobalScore("ETH",currTime,score.start()), 20 ether);

        assertEq(score.getArtScore(cdp,"ETH",currTime,score.start()), 20 ether);
        assertEq(score.getArtGlobalScore("ETH",currTime,score.start()), 20 ether);
    }

    function testFluxCdp() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp = openCdp(12 ether,1 ether);
        manager.frob(cdp, -int(2 ether), 0);

        forwardTime(10);
        manager.flux(cdp, address(this), 1 ether);
        manager.flux("ETH", cdp, address(this), 1 ether);
        forwardTime(10);

        assertEq(score.getInkScore(cdp,"ETH",currTime,score.start()), 200 ether);
        assertEq(score.getInkGlobalScore("ETH",currTime,score.start()), 200 ether);

        assertEq(score.getArtScore(cdp,"ETH",currTime,score.start()), 20 ether);
        assertEq(score.getArtGlobalScore("ETH",currTime,score.start()), 20 ether);
    }

    function testMove() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp = openCdp(10 ether,1 ether);

        forwardTime(10);
        manager.move(cdp, address(this), 1 ether * ONE);
        forwardTime(10);

        assertEq(score.getInkScore(cdp,"ETH",currTime,score.start()), 200 ether);
        assertEq(score.getInkGlobalScore("ETH",currTime,score.start()), 200 ether);

        assertEq(score.getArtScore(cdp,"ETH",currTime,score.start()), 20 ether);
        assertEq(score.getArtGlobalScore("ETH",currTime,score.start()), 20 ether);
    }

    function testQuit() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp = openCdp(10 ether,1 ether);

        forwardTime(10);
        vat.hope(address(manager));
        manager.quit(cdp, address(this));
        forwardTime(15);

        assertEq(score.getInkScore(cdp,"ETH",currTime,score.start()), 100 ether);
        assertEq(score.getInkGlobalScore("ETH",currTime,score.start()), 100 ether);

        assertEq(score.getArtScore(cdp,"ETH",currTime,score.start()), 10 ether);
        assertEq(score.getArtGlobalScore("ETH",currTime,score.start()), 10 ether);
    }

    function testEnter() public {
        weth.deposit.value(10 ether)();
        weth.approve(address(ethJoin), 10 ether);
        ethJoin.join(address(this), 10 ether);
        vat.frob("ETH", address(this), address(this), address(this), 10 ether, 1 ether);
        vat.hope(address(manager));

        timeReset();

        uint time = now;

        score.spin();

        uint cdp = openCdp(0 ether,0 ether);

        forwardTime(15);
        manager.enter(address(this), cdp);
        forwardTime(10);

        assertEq(score.getInkScore(cdp,"ETH",currTime,score.start()), 100 ether);
        assertEq(score.getInkGlobalScore("ETH",currTime,score.start()), 100 ether);

        assertEq(score.getArtScore(cdp,"ETH",currTime,score.start()), 10 ether);
        assertEq(score.getArtGlobalScore("ETH",currTime,score.start()), 10 ether);
    }

    function testShift() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp1 = openCdp(10 ether,1 ether);
        uint cdp2 = openCdp(20 ether,2 ether);

        forwardTime(10);

        assertEq(score.getInkScore(cdp1,"ETH",currTime,score.start()), 100 ether);
        assertEq(score.getInkScore(cdp2,"ETH",currTime,score.start()), 200 ether);
        assertEq(score.getInkGlobalScore("ETH",currTime,score.start()), 300 ether);

        assertEq(score.getArtScore(cdp1,"ETH",currTime,score.start()), 10 ether);
        assertEq(score.getArtScore(cdp2,"ETH",currTime,score.start()), 20 ether);
        assertEq(score.getArtGlobalScore("ETH",currTime,score.start()), 30 ether);

        manager.shift(cdp1,cdp2);

        forwardTime(10);

        assertEq(score.getInkScore(cdp1,"ETH",currTime,score.start()), 100 ether);
        assertEq(score.getInkScore(cdp2,"ETH",currTime,score.start()), 400 ether + 100 ether);
        assertEq(score.getInkGlobalScore("ETH",currTime,score.start()), 600 ether);

        assertEq(score.getArtScore(cdp1,"ETH",currTime,score.start()), 10 ether);
        assertEq(score.getArtScore(cdp2,"ETH",currTime,score.start()), 40 ether + 10 ether);
        assertEq(score.getArtGlobalScore("ETH",currTime,score.start()), 60 ether);
    }


    function testMultipleUsers() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp1 = openCdp(10 ether,1 ether);
        forwardTime(10);
        uint cdp2 = openCdp(20 ether,2 ether);
        forwardTime(10);
        uint cdp3 = openCdp(30 ether,3 ether);
        forwardTime(10);

        assertEq(currTime, time + 30);

        uint expectedTotalInkScore = (30 + 20 * 2 + 10 * 3) * 10 ether;
        uint expectedTotalArtScore = expectedTotalInkScore / 10;

        assertEq(score.getInkScore(cdp1,"ETH",currTime,score.start()), 30 * 10 ether);
        assertEq(score.getInkScore(cdp2,"ETH",currTime,score.start()), 20 * 20 ether);
        assertEq(score.getInkScore(cdp3,"ETH",currTime,score.start()), 10 * 30 ether);
        assertEq(score.getInkGlobalScore("ETH",currTime,score.start()), expectedTotalInkScore);

        assertEq(score.getArtScore(cdp1,"ETH",currTime,score.start()), 30 * 1 ether);
        assertEq(score.getArtScore(cdp2,"ETH",currTime,score.start()), 20 * 2 ether);
        assertEq(score.getArtScore(cdp3,"ETH",currTime,score.start()), 10 * 3 ether);
        assertEq(score.getArtGlobalScore("ETH",currTime,score.start()), expectedTotalArtScore);

        manager.frob(cdp2, -1 * 10 ether, -1 * 1 ether);

        forwardTime(7);

        expectedTotalInkScore += (1 + 2 + 3) * 70 ether - 70 ether;
        expectedTotalArtScore += (1 + 2 + 3) * 7 ether - 7 ether;

        assertEq(score.getInkScore(cdp2,"ETH",currTime,score.start()), 27 * 20 ether - 7 * 10 ether);
        assertEq(score.getArtScore(cdp2,"ETH",currTime,score.start()), 27 * 2 ether - 7 * 1 ether);

        assertEq(score.getInkGlobalScore("ETH",currTime,score.start()), expectedTotalInkScore);
        assertEq(score.getArtGlobalScore("ETH",currTime,score.start()), expectedTotalArtScore);
    }

    function testFrob() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp = openCdp(100 ether, 10 ether);
        forwardTime(10);

        assertEq(score.getInkScore(cdp,"ETH",currTime,score.start()), 10 * 100 ether);
        assertEq(score.getArtScore(cdp,"ETH",currTime,score.start()), 10 * 10 ether);

        manager.frob(cdp, -1 ether, 1 ether);

        forwardTime(15);

        assertEq(score.getInkScore(cdp,"ETH",currTime,score.start()), 25 * 100 ether - 15 ether);
        assertEq(score.getArtScore(cdp,"ETH",currTime,score.start()), 25 * 10 ether + 15 ether);

        manager.frob(cdp, 1 ether, -1 ether);

        forwardTime(17);

        assertEq(score.getInkScore(cdp,"ETH",currTime,score.start()), 25 * 100 ether - 15 ether + 100 * 17 ether);
        assertEq(score.getArtScore(cdp,"ETH",currTime,score.start()), 25 * 10 ether + 15 ether + 10 * 17 ether);
    }

    function testSpin() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp = openCdp(100 ether, 10 ether);
        forwardTime(10);

        score.spin();

        forwardTime(15);

        assertEq(score.getInkScore(cdp,"ETH",currTime,score.start()), 15 * 100 ether);
        assertEq(score.getArtScore(cdp,"ETH",currTime,score.start()), 15 * 10 ether);

        score.spin();

        forwardTime(17);

        manager.frob(cdp, -1 ether, 1 ether);

        forwardTime(13);

        assertEq(score.getInkScore(cdp,"ETH",currTime,score.start()), (17 + 13) * 100 ether - 13 * 1 ether);
        assertEq(score.getArtScore(cdp,"ETH",currTime,score.start()), (17 + 13) * 10 ether + 13 * 1 ether);

        score.spin();

        forwardTime(39);

        assertEq(currTime-score.start(), 39);

        assertEq(score.getInkScore(cdp,"ETH",currTime,score.start()), 39 * 99 ether);
        assertEq(score.getArtScore(cdp,"ETH",currTime,score.start()), 39 * 11 ether);

        // try to calculate past time

        // middle of first round
        assertEq(score.getInkScore(cdp,"ETH",time + 5,time), 5 * 100 ether);

        // middle of second round
        assertEq(score.getInkScore(cdp,"ETH",time + 18,time+10), 8 * 100 ether);

        // middle of third round
        // before the frob
        assertEq(score.getInkScore(cdp,"ETH",time + 25 + 15,time+25), 15 * 100 ether);
        // after the frob
        assertEq(score.getInkScore(cdp,"ETH",time + 25 + 19,time+25), 17 * 100 ether + 2 * 99 ether);
    }

    function testSlash() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp = openCdp(10 ether,1 ether);
        forwardTime(10);

        score.slashScore(cdp,"ETH",10 ether,time);

        forwardTime(15);

        assertEq(score.getSlashScore(cdp,"ETH",now,time),10 ether * 25);
        assertEq(score.getSlashGlobalScore("ETH",now,time),10 ether * 25);
    }

    function testFailedSlashNotFromAdmin() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp = openCdp(10 ether,1 ether);
        forwardTime(10);
        FakeSlasher fakeSlasher = new FakeSlasher();
        fakeSlasher.doSlash(score,cdp,"ETH",10 ether,time);
    }
}
