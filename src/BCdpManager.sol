pragma solidity ^0.5.12;

import { LibNote } from "dss/lib.sol";
import {DssCdpManager} from "./DssCdpManager.sol";
import "./LiquidationMachine.sol";
import {ScoringMachine} from "./ScoringMachine.sol";

contract BCdpManager is DssCdpManager, ScoringMachine, LiquidationMachine {
    constructor(address vat_, address cat_, address pool_, address real_) public
        DssCdpManager(vat_)
        LiquidationMachine(this,VatLike(vat_),CatLike(cat_),pool_,PriceFeedLike(real_))
    {

    }

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    // Open a new cdp for a given usr address.
    function open(
        bytes32 ilk,
        address usr
    ) public note returns (uint) {
        return super.open(ilk,usr);
    }

    // Give the cdp ownership to a dst address.
    function give(
        uint cdp,
        address dst
    ) public note cdpAllowed(cdp) {
        return super.give(cdp,dst);
    }

    // Frob the cdp keeping the generated DAI or collateral freed in the cdp urn address.
    function frob(
        uint cdp,
        int dink,
        int dart
    ) public note cdpAllowed(cdp) {
        super.frob(cdp,dink,dart);

        untop(cdp);
        updateScore(cdp,dink,now);
    }

    // Transfer wad amount of cdp collateral from the cdp address to a dst address.
    function flux(
        uint cdp,
        address dst,
        uint wad
    ) public note cdpAllowed(cdp) {
        super.flux(cdp,dst,wad);
    }

    // Transfer wad amount of any type of collateral (ilk) from the cdp address to a dst address.
    // This function has the purpose to take away collateral from the system that doesn't correspond to the cdp but was sent there wrongly.
    function flux(
        bytes32 ilk,
        uint cdp,
        address dst,
        uint wad
    ) public note cdpAllowed(cdp) {
        super.flux(ilk,cdp,dst,wad);
    }

    // Transfer wad amount of DAI from the cdp address to a dst address.
    function move(
        uint cdp,
        address dst,
        uint rad
    ) public note cdpAllowed(cdp) {
        super.move(cdp,dst,rad);
    }


    // Quit the system, migrating the cdp (ink, art) to a different dst urn
    function quit(
        uint cdp,
        address dst
    ) public note cdpAllowed(cdp) {
        address urn = urns[cdp];
        bytes32 ilk = ilks[cdp];

        untop(cdp);
        (uint ink,) = vat.urns(ilk, urn);
        updateScore(cdp,-toInt(ink),now);

        super.quit(cdp,dst);
    }

    // Import a position from src urn to the urn owned by cdp
    function enter(
        address src,
        uint cdp
    ) public note urnAllowed(src) cdpAllowed(cdp) {
        bytes32 ilk = ilks[cdp];

        untop(cdp);
        (uint ink,) = vat.urns(ilk, src);
        updateScore(cdp,toInt(ink),now);

        super.enter(src,cdp);
    }

    // Move a position from cdpSrc urn to the cdpDst urn
    function shift(
        uint cdpSrc,
        uint cdpDst
    ) public note cdpAllowed(cdpSrc) cdpAllowed(cdpDst) {
        bytes32 ilkSrc = ilks[cdpSrc];

        untop(cdpSrc);
        untop(cdpDst);

        address src = urns[cdpSrc];

        (uint inkSrc,) = vat.urns(ilkSrc, src);

        updateScore(cdpSrc,-toInt(inkSrc),now);
        updateScore(cdpDst, toInt(inkSrc),now);

        super.shift(cdpSrc,cdpDst);
    }

    function quitB(uint cdp) note external cdpAllowed(cdp) {
        quitBScore(cdp);
        quitBLiquidation(cdp);
    }
}
