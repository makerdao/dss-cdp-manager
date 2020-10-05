pragma solidity ^0.5.12;

import { BCdpManagerTestBase, Hevm, FakeUser } from "./BCdpManager.t.sol";
import { JarConnector } from "./JarConnector.sol";

contract JarConnectorTest is BCdpManagerTestBase {
    JarConnector jarConnector;
    uint currTime;

    function setUp() public {
        super.setUp();

        uint[2] memory durations;
        durations[0] = 30 days;
        durations[1] = 5 * 30 days;

        address[] memory gemJoins = new address[](2);
        gemJoins[0] = address(ethJoin);
        gemJoins[1] = address(colJoin);

        bytes32[] memory ilks = new bytes32[](2);
        ilks[0] = "ETH";
        ilks[1] = "COL";

        jarConnector = new JarConnector(address(manager), gemJoins, ilks, durations);
        score.transferOwnership(address(jarConnector));
    }

    function timeReset() internal {
        currTime = now;
        hevm.warp(currTime);
    }

    function forwardTime(uint deltaInSec) internal {
        currTime += deltaInSec;
        hevm.warp(currTime);
    }

    function sendGem(uint wad, address dest) internal returns(uint){
        weth.mint(wad);
        weth.approve(address(ethJoin), wad);
        ethJoin.join(address(this), wad);
        vat.flux("ETH", address(this), dest, wad);
    }

    function openCdp(uint ink, uint art) internal returns(uint){
        uint cdp = manager.open("ETH", address(this));

        weth.mint(ink);
        weth.approve(address(ethJoin), ink);
        ethJoin.join(manager.urns(cdp), ink);

        manager.frob(cdp, int(ink), int(art));

        return cdp;
    }

    function openCdpWithCOL(uint ink, uint art) internal returns(uint) {
        uint cdp = manager.open("COL", address(this));

        col.mint(ink);
        col.approve(address(colJoin), ink);
        colJoin.join(manager.urns(cdp), ink);

        manager.frob(cdp, int(ink), int(art));

        return cdp;
    }

    function testExitEthExplicit() public {
        uint wad = 12345;
        sendGem(wad, address(jarConnector));
        assertEq(vat.gem("ETH", address(jarConnector)), wad);

        jarConnector.gemExit(wad/2, "ETH");
        assertEq(weth.balanceOf(address(jarConnector)), wad/2);
    }

    function testExitEth() public {
        uint wad = 12345;
        sendGem(wad, address(jarConnector));
        assertEq(vat.gem("ETH", address(jarConnector)), wad);

        jarConnector.gemExit("ETH");
        assertEq(weth.balanceOf(address(jarConnector)), wad);
    }

    function testToUser() public {
        FakeUser u1 = new FakeUser();
        FakeUser u2 = new FakeUser();
        FakeUser u3 = new FakeUser();

        uint cdp1 = manager.open("ETH", address(u1));
        uint cdp2 = manager.open("ETH", address(u2));
        uint cdp3 = manager.open("ETH", address(u3));

        assertEq(address(u1), jarConnector.toUser(bytes32(cdp1)));
        assertEq(address(u2), jarConnector.toUser(bytes32(cdp2)));
        assertEq(address(u3), jarConnector.toUser(bytes32(cdp3)));
    }

    function testScore() public {
        timeReset();

        uint cdp1 = openCdp(10 ether, 100 ether);
        uint cdp2 = openCdp(10 ether, 101 ether);

        forwardTime(101);

        assertEq(0, jarConnector.getUserScore(bytes32(cdp1)));
        assertEq(0, jarConnector.getUserScore(bytes32(cdp2)));
        assertEq(0, jarConnector.getUserScore(bytes32(cdp2+1)));

        jarConnector.spin();

        forwardTime(100);

        uint expectedScore1 = 2 * 100 * 100 ether;
        uint expectedScore2 = 2 * 100 * 101 ether;

        assertEq(expectedScore1, jarConnector.getUserScore(bytes32(cdp1)));
        assertEq(expectedScore2, jarConnector.getUserScore(bytes32(cdp2)));
        assertEq(0, jarConnector.getUserScore(bytes32(cdp2+1)));

        assertEq(expectedScore1 + expectedScore2, jarConnector.getGlobalScore());

        forwardTime(30 days);

        expectedScore1 = 2 * (30 days + 100) * 100 ether;
        expectedScore2 = 2 * (30 days + 100) * 101 ether;

        assertEq(expectedScore1, jarConnector.getUserScore(bytes32(cdp1)));
        assertEq(expectedScore2, jarConnector.getUserScore(bytes32(cdp2)));
        assertEq(0, jarConnector.getUserScore(bytes32(cdp2+1)));

        assertEq(expectedScore1 + expectedScore2, jarConnector.getGlobalScore());

        jarConnector.spin();

        assertEq(expectedScore1, jarConnector.getUserScore(bytes32(cdp1)));
        assertEq(expectedScore2, jarConnector.getUserScore(bytes32(cdp2)));
        assertEq(0, jarConnector.getUserScore(bytes32(cdp2+1)));

        assertEq(expectedScore1 + expectedScore2, jarConnector.getGlobalScore());

        forwardTime(5 days);

        uint cdp3 = openCdp(10 ether, 102 ether);

        forwardTime(100 days);

        uint expectedScoreAddition1 = 105 days * 100 ether;
        uint expectedScoreAddition2 = 105 days * 101 ether;

        expectedScore1 += expectedScoreAddition1;
        expectedScore2 += expectedScoreAddition2;
        uint expectedScore3 = 100 days * 102 ether;

        assertEq(expectedScore1, jarConnector.getUserScore(bytes32(cdp1)));
        assertEq(expectedScore2, jarConnector.getUserScore(bytes32(cdp2)));
        assertEq(expectedScore3, jarConnector.getUserScore(bytes32(cdp3)));
        assertEq(0, jarConnector.getUserScore(bytes32(cdp3 + 1)));

        assertEq(expectedScore1 + expectedScore2 + expectedScore3, jarConnector.getGlobalScore());

        // so far 135 days and 100 seconds elapsed, out of total of 180 days
        forwardTime(180 days - 135 days);

        expectedScore1 += (180 days - 135 days) * 100 ether;
        expectedScore2 += (180 days - 135 days) * 101 ether;
        expectedScore3 += (180 days - 135 days) * 102 ether;

        assertEq(expectedScore1, jarConnector.getUserScore(bytes32(cdp1)));
        assertEq(expectedScore2, jarConnector.getUserScore(bytes32(cdp2)));
        assertEq(expectedScore3, jarConnector.getUserScore(bytes32(cdp3)));
        assertEq(0, jarConnector.getUserScore(bytes32(cdp3 + 1)));

        assertEq(expectedScore1 + expectedScore2 + expectedScore3, jarConnector.getGlobalScore());

        jarConnector.spin();

        // should remove first 101 seconds because first round didn't start,
        // and last 100 seconds because spin was called with delay
        expectedScore1 -= 201 * 100 ether;
        expectedScore2 -= 201 * 101 ether;
        expectedScore3 -= 201 * 102 ether;

        assertEq(expectedScore1, jarConnector.getUserScore(bytes32(cdp1)));
        assertEq(expectedScore2, jarConnector.getUserScore(bytes32(cdp2)));
        assertEq(expectedScore3, jarConnector.getUserScore(bytes32(cdp3)));
        assertEq(0, jarConnector.getUserScore(bytes32(cdp3 + 1)));

        assertEq(expectedScore1 + expectedScore2 + expectedScore3, jarConnector.getGlobalScore());
    }

    function testScoreWithMultiIlk() public {
        timeReset();

        uint cdp1 = openCdp(10 ether, 100 ether); // 10 ETH, 100 DAI
        uint cdp2 = openCdpWithCOL(10 ether, 101 ether); // 10 COL, 101 DAI

        forwardTime(101);

        assertEq(jarConnector.round(), 0);

        assertEq(jarConnector.getUserScore(bytes32(cdp1)), 0);
        assertEq(jarConnector.getUserScore(bytes32(cdp2)), 0);
        assertEq(jarConnector.getGlobalScore(), 0);

        jarConnector.spin();
        assertEq(jarConnector.round(), 1);

        forwardTime(30 days);

        uint expectedScore1 = 2 * 30 days * 100 ether;
        uint expectedScore2 = 2 * 30 days * 101 ether;

        assertEq(jarConnector.getUserScore(bytes32(cdp1)), expectedScore1);
        assertEq(jarConnector.getUserScore(bytes32(cdp2)), expectedScore2);

        assertEq(jarConnector.getGlobalScore("ETH"), expectedScore1);
        assertEq(jarConnector.getGlobalScore("COL"), expectedScore2);
        assertEq(jarConnector.getGlobalScore(), expectedScore1 + expectedScore2);

        jarConnector.spin();
        assertEq(jarConnector.round(), 2);

        forwardTime(5 * 30 days);

        expectedScore1 += 5 * 30 days * 100 ether;
        expectedScore2 += 5 * 30 days * 101 ether;

        assertEq(jarConnector.getUserScore(bytes32(cdp1)), expectedScore1);
        assertEq(jarConnector.getUserScore(bytes32(cdp2)), expectedScore2);

        assertEq(jarConnector.getGlobalScore("ETH"), expectedScore1);
        assertEq(jarConnector.getGlobalScore("COL"), expectedScore2);
        assertEq(jarConnector.getGlobalScore(), expectedScore1 + expectedScore2);
    }

    function testSpinTooEarly() public {
        timeReset();
        assertEq(jarConnector.round(), 0);
        forwardTime(101);
        jarConnector.spin();
        forwardTime(29 days);
        jarConnector.spin();
        assertEq(jarConnector.round(), 1);
        forwardTime(1 days);
        jarConnector.spin();
        assertEq(jarConnector.round(), 2);
        forwardTime(100 days);
        jarConnector.spin();
        assertEq(jarConnector.round(), 2);
        forwardTime(50 days);
        jarConnector.spin();
        assertEq(jarConnector.round(), 3);
    }
}
