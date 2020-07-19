pragma solidity ^0.5.12;

import { LibNote } from "dss/lib.sol";
import {DssCdpManager} from "./DssCdpManager.sol";
import {ScoringMachine} from "./ScoringMachine.sol";

contract VatLike {
    function urns(bytes32 ilk, address u) public view returns (uint ink, uint art);
    function ilks(bytes32 ilk) public view returns(uint Art, uint rate, uint spot, uint line, uint dust);
    function frob(bytes32 i, address u, address v, address w, int dink, int dart) external;
    function move(address src, address dst, uint256 rad) external;
}

contract CatLike {
    function ilks(bytes32) public returns(address flip, uint256 chop, uint256 lump);
}

contract PriceFeedLike {
    function read(bytes32 ilk) external view returns(bytes32);
}

contract LiquidationMachine is LibNote, ScoringMachine {
    VatLike                   public vat;
    CatLike                   public cat;
    DssCdpManager             public man;
    address                   public pool;
    PriceFeedLike             public real;

    mapping(uint => uint)     public tic;  // time of bite
    mapping(uint => uint)     public cushion; // how much was topped in art units

    uint constant             public GRACE = 1 hours;

    mapping (uint => bool)    public out;

    modifier onlyPool {
        require(msg.sender == pool, "not-pool");
        _;
    }

    constructor(DssCdpManager man_,VatLike vat_, CatLike cat_, address pool_, PriceFeedLike real_) public {
        man = man_;
        vat = vat_;
        cat = cat_;
        pool = pool_;
        real = real_;
    }

    function quitBLiquidation(uint cdp) internal {
        untop(cdp);
        out[cdp] = true;
    }

    function topup(uint cdp, uint dtopup) external onlyPool {
        if(out[cdp]) return;

        address urn = man.urns(cdp);
        bytes32 ilk = man.ilks(cdp);

        (,uint rate,,,) = vat.ilks(ilk);
        uint dtab = mul(rate, dtopup);

        vat.move(address(pool),address(this),dtab);
        vat.frob(ilk,urn,urn,address(this),0,-int(dtopup));

        cushion[cdp] = add(cushion[cdp], dtopup);
    }

    function bitten(uint cdp) public view returns(bool) {
        return tic[cdp] + GRACE > now;
    }

    function untop(uint cdp) internal {
        require(! bitten(cdp), "untop: cdp was already bitten");

        uint top = cushion[cdp];
        if(top == 0) return; // nothing to do

        bytes32 ilk = man.ilks(cdp);
        address urn = man.urns(cdp);

        (,uint rate,,,) = vat.ilks(ilk);
        uint dtab = mul(rate, top); // TODO - check resolution

        cushion[cdp] = 0;

        // move topping to pool
        vat.frob(ilk, urn, urn, urn, 0, toInt(top));
        vat.move(urn,address(pool),dtab);
    }

    function untopByPool(uint cdp) external onlyPool {
        untop(cdp);
    }

    function doBite(uint cdp, uint dart, bytes32 ilk, address urn, uint dink) internal {
        (,uint rate,,,) = vat.ilks(ilk);
        uint dtab = mul(rate, dart);

        vat.move(address(pool),address(this),dtab);

        vat.frob(ilk,urn,urn,address(this),0,-int(dart));
        vat.frob(ilk,urn,msg.sender,urn,-int(dink),0);

        updateScore(cdp,toInt(dink),now);
    }

    function bite(uint cdp, uint dart) external onlyPool returns(uint dink){
        address urn = man.urns(cdp);
        bytes32 ilk = man.ilks(cdp);

        (uint ink, uint art) = vat.urns(ilk,urn);
        art = add(art, cushion[cdp]);
        (,uint rate,uint spotValue,,) = vat.ilks(ilk);

        require(dart <= art, "debt is too low");

        // verify cdp is unsafe now
        if(! bitten(cdp)) {
            require(mul(art,rate) > mul(ink,spotValue), "bite: cdp is safe");
            require(cushion[cdp] > 0, "bite: not-topped");
            tic[cdp] = now;
        }

        (,uint chop,) = cat.ilks(ilk);
        uint tab = rmul(mul(dart, rate), chop);
        bytes32 realtimePrice = real.read(ilk);

        dink = rmul(tab, 1e18) / uint(realtimePrice); // TODO probably need to adjust from rad to wad

        if(dart >= cushion[cdp]) {
            dart = sub(dart, cushion[cdp]);
            cushion[cdp] = 0;
        }
        else {
            cushion[cdp] = sub(cushion[cdp],dart);
            dart = 0;
        }

        doBite(cdp, dart, ilk, urn, dink);
    }
}
