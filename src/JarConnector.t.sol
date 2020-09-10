pragma solidity ^0.5.12;

import { BCdpManagerTestBase, Hevm, FakeUser } from "./BCdpManager.t.sol";
import { JarConnector } from "./JarConnector.sol";

contract JarConnectorTest is BCdpManagerTestBase {
    JarConnector jarConnector;
    uint currTime;

    function setUp() public {
        super.setUp();

        jarConnector = new JarConnector(address(manager), address(ethJoin), "ETH");
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

    function testExitEthExplicit() public {
        uint wad = 12345;
        sendGem(wad, address(jarConnector));
        assertEq(vat.gem("ETH", address(jarConnector)), wad);

        jarConnector.ethExit(wad/2, "ETH");
        assertEq(weth.balanceOf(address(jarConnector)), wad/2);
    }

    function testExitEth() public {
        uint wad = 12345;
        sendGem(wad, address(jarConnector));
        assertEq(vat.gem("ETH", address(jarConnector)), wad);

        jarConnector.ethExit();
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

        forwardTime(100);

        uint expectedScore1 = 100 * 100 ether;
        uint expectedScore2 = 101 * 100 ether;

        assertEq(expectedScore1, jarConnector.getUserScore(bytes32(cdp1)));
        assertEq(expectedScore2, jarConnector.getUserScore(bytes32(cdp2)));
        assertEq(0, jarConnector.getUserScore(bytes32(cdp2+1)));

        assertEq(expectedScore1 + expectedScore2, jarConnector.getGlobalScore());
    }
}
