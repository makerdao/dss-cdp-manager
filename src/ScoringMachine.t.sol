pragma solidity ^0.5.12;

import { BCdpManagerTestBase, Hevm, FakeUser } from "./BCdpManager.t.sol";
import { BCdpScoreV2 } from "./BCdpScoreV2.sol";
import { BCdpScoreConnector } from "./BCdpScoreConnector.sol";
import { LiquidationMachine } from "./LiquidationMachine.sol";
import { ScoringMachine } from "../user-rating/contracts/score/ScoringMachine.sol";


contract ScoringMachineTest is BCdpManagerTestBase {
    uint currTime;

    BCdpScoreV2 score;
    MockScoringMachine sm;

    function setUp() public {
        super.setUp();

        currTime = now;
        hevm.warp(currTime);

        score = BCdpScoreV2(address(BCdpScoreConnector(manager).score()));
        sm = new MockScoringMachine();
    }

    function openCdp(uint ink, uint art) internal returns(uint){
        uint cdp = manager.open("ETH", address(this));

        weth.mint(ink);
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

        score.spin();

        uint cdp = openCdp(0 ether, 0 ether);
        forwardTime(10);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 0);
        assertEq(score.getInkGlobalScore("ETH", currTime, score.start()), 0);

        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 0);
        assertEq(score.getArtGlobalScore("ETH", currTime, score.start()), 0);
    }

    function testShiftCdp() public {
        timeReset();

        score.spin();

        uint cdp = openCdp(1 ether, 1 ether);
        forwardTime(10);
        manager.give(cdp, address(123));
        assertEq(manager.owns(cdp), address(123));
        forwardTime(10);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 20 ether);
        assertEq(score.getInkGlobalScore("ETH", currTime, score.start()), 20 ether);

        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 20 ether);
        assertEq(score.getArtGlobalScore("ETH", currTime, score.start()), 20 ether);
    }

    function testFluxCdp() public {
        timeReset();

        score.spin();

        uint cdp = openCdp(12 ether, 1 ether);
        manager.frob(cdp, -int(2 ether), 0);

        forwardTime(10);
        manager.flux(cdp, address(this), 1 ether);
        manager.flux("ETH", cdp, address(this), 1 ether);
        forwardTime(10);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 200 ether);
        assertEq(score.getInkGlobalScore("ETH", currTime, score.start()), 200 ether);

        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 20 ether);
        assertEq(score.getArtGlobalScore("ETH", currTime, score.start()), 20 ether);
    }

    function testMove() public {
        timeReset();

        score.spin();

        uint cdp = openCdp(10 ether, 1 ether);

        forwardTime(10);
        manager.move(cdp, address(this), 1 ether * WAD);
        forwardTime(10);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 200 ether);
        assertEq(score.getInkGlobalScore("ETH", currTime, score.start()), 200 ether);

        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 20 ether);
        assertEq(score.getArtGlobalScore("ETH", currTime, score.start()), 20 ether);
    }

    function testQuit() public {
        timeReset();

        score.spin();

        uint cdp = openCdp(10 ether, 1 ether);

        forwardTime(10);
        vat.hope(address(manager));
        manager.quit(cdp, address(this));
        forwardTime(15);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 100 ether);
        assertEq(score.getInkGlobalScore("ETH", currTime, score.start()), 100 ether);

        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 10 ether);
        assertEq(score.getArtGlobalScore("ETH", currTime, score.start()), 10 ether);
    }

    function testEnter() public {
        weth.mint(10 ether);
        weth.approve(address(ethJoin), 10 ether);
        ethJoin.join(address(this), 10 ether);
        vat.frob("ETH", address(this), address(this), address(this), 10 ether, 1 ether);
        vat.hope(address(manager));

        timeReset();

        score.spin();

        uint cdp = openCdp(0 ether, 0 ether);

        forwardTime(15);
        manager.enter(address(this), cdp);
        forwardTime(10);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 100 ether);
        assertEq(score.getInkGlobalScore("ETH", currTime, score.start()), 100 ether);

        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 10 ether);
        assertEq(score.getArtGlobalScore("ETH", currTime, score.start()), 10 ether);
    }

    function testShift() public {
        timeReset();

        score.spin();

        uint cdp1 = openCdp(10 ether, 1 ether);
        uint cdp2 = openCdp(20 ether, 2 ether);

        forwardTime(10);

        assertEq(score.getInkScore(cdp1, "ETH", currTime, score.start()), 100 ether);
        assertEq(score.getInkScore(cdp2, "ETH", currTime, score.start()), 200 ether);
        assertEq(score.getInkGlobalScore("ETH", currTime, score.start()), 300 ether);

        assertEq(score.getArtScore(cdp1, "ETH", currTime, score.start()), 10 ether);
        assertEq(score.getArtScore(cdp2, "ETH", currTime, score.start()), 20 ether);
        assertEq(score.getArtGlobalScore("ETH", currTime, score.start()), 30 ether);

        manager.shift(cdp1, cdp2);

        forwardTime(10);

        assertEq(score.getInkScore(cdp1, "ETH", currTime, score.start()), 100 ether);
        assertEq(score.getInkScore(cdp2, "ETH", currTime, score.start()), 400 ether + 100 ether);
        assertEq(score.getInkGlobalScore("ETH", currTime, score.start()), 600 ether);

        assertEq(score.getArtScore(cdp1, "ETH", currTime, score.start()), 10 ether);
        assertEq(score.getArtScore(cdp2, "ETH", currTime, score.start()), 40 ether + 10 ether);
        assertEq(score.getArtGlobalScore("ETH", currTime, score.start()), 60 ether);
    }


    function testMultipleUsers() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp1 = openCdp(10 ether, 1 ether);
        forwardTime(10);
        uint cdp2 = openCdp(20 ether, 2 ether);
        forwardTime(10);
        uint cdp3 = openCdp(30 ether, 3 ether);
        forwardTime(10);

        assertEq(currTime, time + 30);

        uint expectedTotalInkScore = (30 + 20 * 2 + 10 * 3) * 10 ether;
        uint expectedTotalArtScore = expectedTotalInkScore / 10;

        assertEq(score.getInkScore(cdp1, "ETH", currTime, score.start()), 30 * 10 ether);
        assertEq(score.getInkScore(cdp2, "ETH", currTime, score.start()), 20 * 20 ether);
        assertEq(score.getInkScore(cdp3, "ETH", currTime, score.start()), 10 * 30 ether);
        assertEq(score.getInkGlobalScore("ETH", currTime, score.start()), expectedTotalInkScore);

        assertEq(score.getArtScore(cdp1, "ETH", currTime, score.start()), 30 * 1 ether);
        assertEq(score.getArtScore(cdp2, "ETH", currTime, score.start()), 20 * 2 ether);
        assertEq(score.getArtScore(cdp3, "ETH", currTime, score.start()), 10 * 3 ether);
        assertEq(score.getArtGlobalScore("ETH", currTime, score.start()), expectedTotalArtScore);

        manager.frob(cdp2, -1 * 10 ether, -1 * 1 ether);

        forwardTime(7);

        expectedTotalInkScore += (1 + 2 + 3) * 70 ether - 70 ether;
        expectedTotalArtScore += (1 + 2 + 3) * 7 ether - 7 ether;

        assertEq(score.getInkScore(cdp2, "ETH", currTime, score.start()), 27 * 20 ether - 7 * 10 ether);
        assertEq(score.getArtScore(cdp2, "ETH", currTime, score.start()), 27 * 2 ether - 7 * 1 ether);

        assertEq(score.getInkGlobalScore("ETH", currTime, score.start()), expectedTotalInkScore);
        assertEq(score.getArtGlobalScore("ETH", currTime, score.start()), expectedTotalArtScore);
    }

    function testFrob() public {
        timeReset();

        score.spin();

        uint cdp = openCdp(100 ether, 10 ether);
        forwardTime(10);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 10 * 100 ether);
        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 10 * 10 ether);

        manager.frob(cdp, -1 ether, 1 ether);

        forwardTime(15);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 25 * 100 ether - 15 ether);
        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 25 * 10 ether + 15 ether);

        manager.frob(cdp, 1 ether, -1 ether);

        forwardTime(17);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 25 * 100 ether - 15 ether + 100 * 17 ether);
        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 25 * 10 ether + 15 ether + 10 * 17 ether);
    }

    function testSpin() public {
        timeReset();

        uint time = now;

        score.spin();

        uint cdp = openCdp(100 ether, 10 ether);
        forwardTime(10);

        score.spin();

        forwardTime(15);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 15 * 100 ether);
        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 15 * 10 ether);

        score.spin();

        forwardTime(17);

        manager.frob(cdp, -1 ether, 1 ether);

        forwardTime(13);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), (17 + 13) * 100 ether - 13 * 1 ether);
        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), (17 + 13) * 10 ether + 13 * 1 ether);

        score.spin();

        forwardTime(39);

        assertEq(currTime-score.start(), 39);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 39 * 99 ether);
        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 39 * 11 ether);

        // try to calculate past time

        // middle of first round
        assertEq(score.getInkScore(cdp, "ETH", time + 5, time), 5 * 100 ether);

        // middle of second round
        assertEq(score.getInkScore(cdp, "ETH", time + 18, time+10), 8 * 100 ether);

        // middle of third round
        // before the frob
        assertEq(score.getInkScore(cdp, "ETH", time + 25 + 15, time+25), 15 * 100 ether);
        // after the frob
        assertEq(score.getInkScore(cdp, "ETH", time + 25 + 19, time+25), 17 * 100 ether + 2 * 99 ether);
    }

    function testSlashHappy() public {
        timeReset();

        score.spin();

        uint cdp = openCdp(10 ether, 1 ether);
        manager.move(cdp, address(this), 1 ether * RAY);

        forwardTime(10 * 30 days);

        uint scoreBeforeCheating = score.getArtScore(cdp, "ETH", currTime, score.start());
        assertEq(scoreBeforeCheating, 1 ether * 10 * 30 days);

        address urn = manager.urns(cdp);
        assertEq(vat.dai(address(this)), 1 ether * RAY);
        vat.frob("ETH", urn, urn, address(this), 0, -1 ether / 2);

        forwardTime(1 days);

        uint scoreAfterCheating = score.getArtScore(cdp, "ETH", currTime, score.start());
        assertEq(scoreAfterCheating, 1 ether * 301 days);

        score.slashScore(cdp);

        uint scoreAfterSlashing = score.getArtScore(cdp, "ETH", currTime, score.start());

        assertEq(scoreAfterCheating, scoreAfterSlashing + 30 days * 1 ether / 2);
    }

    function testSlashBeforeOneMonth() public {
        timeReset();

        score.spin();

        uint cdp = openCdp(10 ether, 1 ether);
        manager.move(cdp, address(this), 1 ether * RAY);

        forwardTime(25 days);

        uint scoreBeforeCheating = score.getArtScore(cdp, "ETH", currTime, score.start());
        assertEq(scoreBeforeCheating, 1 ether * 25 days);

        address urn = manager.urns(cdp);
        assertEq(vat.dai(address(this)), 1 ether * RAY);
        vat.frob("ETH", urn, urn, address(this), 0, -1 ether / 2);

        forwardTime(1 days);

        uint scoreAfterCheating = score.getArtScore(cdp, "ETH", currTime, score.start());
        assertEq(scoreAfterCheating, 1 ether * 26 days);

        score.slashScore(cdp);

        uint scoreAfterSlashing = score.getArtScore(cdp, "ETH", currTime, score.start());

        assertEq(scoreAfterCheating, scoreAfterSlashing + 26 days * 1 ether / 2);
    }

    function testSlashBelowZero() public {
        timeReset();

        score.spin();

        forwardTime(30 days);

        uint cdp = openCdp(10 ether, 1 ether);
        manager.move(cdp, address(this), 1 ether * RAY);

        forwardTime(25 days);

        uint scoreBeforeCheating = score.getArtScore(cdp, "ETH", currTime, score.start());
        assertEq(scoreBeforeCheating, 1 ether * 25 days);

        address urn = manager.urns(cdp);
        assertEq(vat.dai(address(this)), 1 ether * RAY);
        vat.frob("ETH", urn, urn, address(this), 0, -1 ether);

        forwardTime(1 days);

        uint scoreAfterCheating = score.getArtScore(cdp, "ETH", currTime, score.start());
        assertEq(scoreAfterCheating, 1 ether * 26 days);

        score.slashScore(cdp);

        uint scoreAfterSlashing = score.getArtScore(cdp, "ETH", currTime, score.start());

        assertEq(0, scoreAfterSlashing);
    }

    function testFailSlash() public {
        timeReset();

        score.spin();

        uint cdp = openCdp(10 ether, 1 ether);
        manager.move(cdp, address(this), 1 ether * RAY);

        forwardTime(250 days);

        uint scoreBeforeCheating = score.getArtScore(cdp, "ETH", currTime, score.start());
        assertEq(scoreBeforeCheating, 1 ether * 250 days);

        forwardTime(2 days);

        // no cheats
        score.slashScore(cdp);
    }

    function testBite() public {
        timeReset();

        score.spin();

        uint cdp = openCdp(0 ether, 0 ether);
        reachBitePrice(cdp);
        forwardTime(10);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 10 * 1 ether);
        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 10 * 50 ether);

        // bite
        address urn = manager.urns(cdp);
        (uint inkBefore,) = vat.urns("ETH", urn);
        liquidator.doBite(pool, cdp, 25 ether, 0);
        assert(LiquidationMachine(manager).bitten(cdp));
        (uint inkAfter,) = vat.urns("ETH", urn);

        forwardTime(10);

        assertEq(score.getInkScore(cdp, "ETH", currTime, score.start()), 20 * 1 ether - 10 * (inkBefore - inkAfter));
        assertEq(score.getArtScore(cdp, "ETH", currTime, score.start()), 10 * 50 ether + 10 * 25 ether);
    }

    // Scoring Machine Unit Tests
    // ============================
    function testUpdateAssetScoreWithMinValue() public {
        int256 _INT256_MIN = -2**255;
        uint time = now;

        resetAndMakeFakeScore(time);

        uint score_; uint balance;

        sm._updateAssetScore("user", "ETH", _INT256_MIN, time);
        score_ = sm._getScore("user", "ETH", now, time, time);
        assert(score_ > 0);
        (score_, balance,) = sm._getAssetScore("user", "ETH");
        // Math calc would underflow when uint(_INT256_MIN) is performed.
        // Hence, balance will be set to 0
        assert(balance == 0);
    }

    function testUpdateAssetScoreWithMaxValue() public {
        int256 _INT256_MAX = 2**255 - 1;
        uint time = now;

        resetAndMakeFakeScore(time);

        uint score_; uint balance;
        (, balance,) = sm._getAssetScore("user", "ETH");
        assert(balance < (uint(-1) - uint(_INT256_MAX)));

        sm._updateAssetScore("user", "ETH", _INT256_MAX, time);
        score_ = sm._getScore("user", "ETH", now, time, time);
        assert(score_ > 0);
        (score_, balance,) = sm._getAssetScore("user", "ETH");
        // Math calc would not overflow as uint(_INT256_MAX) is converted to 256 bit value
        // which is less than 2^256-1, henve balance will be increased
        assert(balance > 0);
    }

    function resetAndMakeFakeScore(uint time) internal {
        uint score_; uint balance;
        hevm.warp(time);

        sm.spin();
        forwardTime(10);
        sm._updateScore("user", "ETH", 1 ether, now);
        forwardTime(10);
        sm._updateScore("user", "ETH", 1 ether, now);
        score_ = sm._getScore("user", "ETH", now, time, time);
        assert(score_ > 0);
        (score_, balance,) = sm._getAssetScore("user", "ETH");
        assert(balance > 0);
    }
}

contract MockScoringMachine is ScoringMachine {
    function _updateAssetScore(bytes32 user, bytes32 asset, int dbalance, uint time) public {
        super.updateAssetScore(user, asset, dbalance, time);
    }

    function _getScore(bytes32 user, bytes32 asset, uint time, uint spinStart, uint checkPointHint) public view returns(uint score) {
        return super.getScore(user, asset, time, spinStart, checkPointHint);
    }

    function _updateScore(bytes32 user, bytes32 asset, int dbalance, uint time) public {
        super.updateScore(user, asset, dbalance, time);
    }

    function _getAssetScore(bytes32 user, bytes32 asset) public view returns (uint, uint, uint) {
        AssetScore memory s = userScore[user][asset];
        return (s.score, s.balance, s.last);
    }
}
