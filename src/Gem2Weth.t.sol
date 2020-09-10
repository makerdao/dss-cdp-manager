pragma solidity ^0.5.12;

import { BCdpManagerTestBase, Hevm, FakeUser } from "./BCdpManager.t.sol";
import { Gem2Weth } from "./Gem2Weth.sol";

contract Gem2WethTest is BCdpManagerTestBase {
    Gem2Weth gem2Weth;

    function setUp() public {
        super.setUp();

        gem2Weth = new Gem2Weth(address(vat), address(ethJoin), "ETH");
    }

    function sendGem(uint wad, address dest) internal returns(uint){
        weth.mint(wad);
        weth.approve(address(ethJoin), wad);
        ethJoin.join(address(this), wad);
        vat.flux("ETH", address(this), dest, wad);
    }

    function testExitEthExplicit() public {
        uint wad = 12345;
        sendGem(wad, address(gem2Weth));
        assertEq(vat.gem("ETH", address(gem2Weth)), wad);

        gem2Weth.ethExit(wad/2, "ETH");
        assertEq(weth.balanceOf(address(gem2Weth)), wad/2);
    }

    function testExitEth() public {
        uint wad = 12345;
        sendGem(wad, address(gem2Weth));
        assertEq(vat.gem("ETH", address(gem2Weth)), wad);

        gem2Weth.ethExit();
        assertEq(weth.balanceOf(address(gem2Weth)), wad);
    }
}
