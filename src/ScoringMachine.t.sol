pragma solidity ^0.5.12;

import {BCdpManagerTestBase, Hevm, FakeUser} from "./BCdpManager.t.sol_";
import {ScoringMachine} from "./ScoringMachine.sol";

contract ScordingMachineTest is BCdpManagerTestBase {
    FakeUser user1;
    FakeUser user2;
    FakeUser user3;

    uint currTime;

    ScoringMachine score;

    function setUp() public {
        super.setUp();

        currTime = now;
        hevm.warp(currTime);

        score = ScoringMachine(manager);
    }

    function openCdp(uint ink) internal returns(uint){
        uint cdp = manager.open("ETH", address(this));

        weth.deposit.value(ink)();
        weth.approve(address(ethJoin), ink);
        ethJoin.join(manager.urns(cdp), ink);

        manager.frob(cdp, int(ink), 0);

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

        score.spin(currTime,currTime + 3 weeks);

        uint cdp1 = openCdp(1 ether);
        forwardTime(10);
        uint cdp2 = openCdp(2 ether);
        forwardTime(10);
        uint cdp3 = openCdp(3 ether);
        forwardTime(10);


        assertEq(score.round(), 1);
        assertEq(currTime, time + 30);

        uint expectedTotalScore = (30 + 20 * 2 + 10 * 3) * 1 ether;

        (uint score1, uint totalScore1) = score.getScore(cdp1, score.round(), currTime);
        assertEq(score1, 30 * 1 ether);
        assertEq(totalScore1, expectedTotalScore);

        (uint score2, uint totalScore2) = score.getScore(cdp2, score.round(), currTime);
        assertEq(score2, 20 * 2 ether);
        assertEq(totalScore2, expectedTotalScore);

        (uint score3, uint totalScore3) = score.getScore(cdp3, score.round(), currTime);
        assertEq(score3, 10 * 3 ether);
        assertEq(totalScore3, expectedTotalScore);

        manager.frob(cdp2, -1 * 1 ether, 0);

        forwardTime(7);

        expectedTotalScore += (1 + 2 + 3) * 7 ether - 7 ether;

        (uint newScore2, uint newTotalScore2) = score.getScore(cdp2, score.round(), currTime);
        assertEq(newScore2, 27 * 2 ether - 7 * 1 ether);
        assertEq(newTotalScore2, expectedTotalScore);
    }
}
