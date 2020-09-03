pragma solidity ^0.5.12;

import { LibNote } from "dss/lib.sol";
import {BCdpManager} from "./../BCdpManager.sol";
import {Math} from "./../Math.sol";

import { DSAuth } from "ds-auth/auth.sol";

contract VatLike {
    function urns(bytes32 ilk, address u) public view returns (uint ink, uint art);
    function ilks(bytes32 ilk) public view returns(uint Art, uint rate, uint spot, uint line, uint dust);
    function flux(bytes32 ilk, address src, address dst, uint256 wad) external;
    function move(address src, address dst, uint256 rad) external;
    function hope(address usr) external;
    function dai(address usr) external view returns(uint);
}

contract PriceFeedLike {
    function peek(bytes32 ilk) external view returns(bytes32,bool);
}

contract SpotLike {
    function par() external view returns (uint256);
    function ilks(bytes32 ilk) external view returns (address pip, uint mat);
}

contract OSMLike {
    function peep() external view returns(bytes32,bool);
    function hop()  external view returns(uint16);
    function zzz()  external view returns(uint64);
}

contract Pool is Math, DSAuth {
    address[] public members;
    mapping(bytes32 => bool) public ilks;
    uint                     public minArt; // min debt to share among members
    uint                     public shrn; // share profit % numerator
    uint                     public shrd; // share profit % denumerator
    mapping(address => uint) public rad; // mapping from member to its dai balance in rad

    VatLike                   public vat;
    BCdpManager               public man;
    SpotLike                  public spot;
    address                   public jar;

    mapping(uint => CdpData) cdpData;
    struct CdpData {
        uint       art;        // topup in art units
        uint       cushion;    // cushion in rad units
        address[]  members;    // liquidators that are in
        uint[]     bite;       // how much was already bitten
    }

    function getCdpData(uint cdp) external view returns(uint art, uint cushion, address[] memory members, uint[] memory bite) {
        art = cdpData[cdp].art;
        cushion = cdpData[cdp].cushion;
        members = cdpData[cdp].members;
        bite = cdpData[cdp].bite;
    }

    mapping(bytes32 => OSMLike) public osm; // mapping from ilk to osm

    modifier onlyMember {
        bool member = false;
        for(uint i = 0 ; i < members.length ; i++) {
            if(members[i] == msg.sender) member = true;
        }
        require(member, "not-member");
        _;
    }

    constructor(address vat_, address jar_, address spot_) public {
        spot = SpotLike(spot_);
        vat = VatLike(vat_);
        jar = jar_;
    }

    function setCdpManager(BCdpManager man_) external auth { // TODO - make it settable only once, or with timelock
        man = man_;
        vat.hope(address(man));
    }

    function setOsm(bytes32 ilk_, address  osm_) external auth { // TODO - make it settable only once, or with timelock
        osm[ilk_] = OSMLike(osm_);
    }

    function setMembers(address[] calldata members_) external auth {
        members = members_;
    }

    function setIlk(bytes32 ilk, bool set) external auth {
        ilks[ilk] = set;
    }

    function setMinArt(uint minArt_) external auth {
        minArt = minArt_;
    }

    function setProfitParams(uint num, uint den) external auth {
        shrn = num;
        shrd = den;
    }

    function deposit(uint radVal) external onlyMember {
        vat.move(msg.sender, address(this),radVal);
        rad[msg.sender] = add(rad[msg.sender],radVal);
    }

    function withdraw(uint radVal) external onlyMember {
        require(rad[msg.sender] >= radVal, "withdraw: insufficient balance");
        rad[msg.sender] = sub(rad[msg.sender],radVal);
        vat.move(address(this),msg.sender,radVal);
    }

    function getIndex(address[] storage array, address elm) internal view returns(uint) {
        for(uint i = 0 ; i < array.length ; i++) {
            if(array[i] == elm) return i;
        }

        return uint(-1);
    }

    function removeElement(address[] memory array, uint index) internal pure returns(address[] memory newArray) {
        if(index >= array.length) {
            newArray = array;
        }
        else {
            newArray = new address[](array.length - 1);
            for(uint i = 0 ; i < array.length ; i++) {
                if(i == index) continue;
                if(i < index) newArray[i] = array[i];
                else newArray[i-1] = array[i];
            }
        }
    }

    function chooseMember(uint cdp, uint radVal, address[] memory candidates) public view returns(address[] memory winners) {
        if(candidates.length == 0) return candidates;

        uint chosen = uint(keccak256(abi.encodePacked(cdp,now / 1 hours))) % candidates.length;
        address winner = candidates[chosen];

        if(rad[winner] < radVal) return chooseMember(cdp,radVal, removeElement(candidates, chosen));

        winners = new address[](1);
        winners[0] = candidates[chosen];
        return winners;
    }

    function chooseMembers(uint radVal, address[] memory candidates) public view returns(address[] memory winners) {
        if(candidates.length == 0) return candidates;

        uint need = add(1,radVal / candidates.length);
        for(uint i = 0 ; i < candidates.length ; i++) {
            if(rad[candidates[i]] < need) {
                return chooseMembers(radVal, removeElement(candidates, i));
            }
        }

        winners = candidates;
    }

    function hypoTopAmount(uint cdp) internal view returns(int dart, int dtab, uint art, bool should) {
        address urn = man.urns(cdp);
        bytes32 ilk = man.ilks(cdp);

        uint ink;
        (ink, art) = vat.urns(ilk,urn);

        if(! ilks[ilk]) return (0,0,art,false);

        (bytes32 peep, bool valid) = osm[ilk].peep();

        // price feed invalid
        if(! valid) return (0,0,art,false);

        // too early to topup
        should = (now >= add(uint(osm[ilk].zzz()),uint(osm[ilk].hop())/2));

        (,uint rate,,,) = vat.ilks(ilk);

        (, uint mat) = spot.ilks(ilk);
        uint par = spot.par();

        uint nextVatSpot = rdiv(rdiv(mul(uint(peep), uint(10 ** 9)), par), mat);

        // rate * art <= spot * ink
        // art <= spot * ink / rate
        uint maximumArt = mul(nextVatSpot,ink) / rate;

        dart = (int(art) - int(maximumArt));
        dtab = mul(rate, dart);
    }

    function topAmount(uint cdp) public view returns(int dart, int dtab, uint art) {
        bool should;
        (dart,dtab,art,should) = hypoTopAmount(cdp);
        if(! should) return (0,0,art);
    }

    function resetCdp(uint cdp) internal {
        address[] memory winners = cdpData[cdp].members;

        if(winners.length == 0) return;

        uint art = cdpData[cdp].art;
        uint cushion = cdpData[cdp].cushion;

        uint perUserArt = cdpData[cdp].art / winners.length;
        for(uint i = 0 ; i < winners.length ; i++) {
            if(perUserArt <= cdpData[cdp].bite[i]) continue; // nothing to refund
            uint refundArt = sub(perUserArt,cdpData[cdp].bite[i]);
            rad[winners[i]] = add(rad[winners[i]],mul(refundArt,cushion)/art);
        }

        cdpData[cdp].art = 0;
        cdpData[cdp].cushion = 0;
        delete cdpData[cdp].members;
        delete cdpData[cdp].bite;
    }

    function setCdp(uint cdp, address[] memory winners, uint art, uint dradVal) internal {
        uint drad = add(1,dradVal / winners.length); // round up
        for(uint i = 0 ; i < winners.length ; i++) {
            rad[winners[i]] = sub(rad[winners[i]], drad);
        }

        cdpData[cdp].art = art;
        cdpData[cdp].cushion = dradVal;
        cdpData[cdp].members = winners;
        cdpData[cdp].bite = new uint[](winners.length);
    }

    function topupInfo(uint cdp) public view returns(int dart, int dtab, uint art, bool should, address[] memory winners) {
        (dart,dtab,art,should) = hypoTopAmount(cdp);
        if(art < minArt) {
            winners = chooseMember(cdp, uint(dtab), members);
        }
        else winners = chooseMembers(uint(dtab), members);
    }

    function topup(uint cdp) external onlyMember {
        require(man.cushion(cdp) == 0, "topup: already-topped");
        require(! man.bitten(cdp), "topup: already-bitten");

        (int dart, int dtab, uint art,bool should,address[] memory winners) = topupInfo(cdp);

        require(should, "topup: no-need");

        resetCdp(cdp);

        require(winners.length > 0, "topup: members-are-broke");
        // for small amounts, only winner can topup
        if(art < minArt) require(winners[0] == msg.sender,"topup: only-winner-can-topup");

        setCdp(cdp, winners, uint(art), uint(dtab));

        man.topup(cdp, uint(dart));
    }

    function untop(uint cdp) external onlyMember {
        require(man.cushion(cdp) == 0, "untop: should-be-untopped-by-user");
        require(! man.bitten(cdp), "topup: in-bite-process");

        resetCdp(cdp);
    }

    function bite(uint cdp, uint dart, uint minInk) external onlyMember returns(uint dMemberInk){
        uint index = getIndex(cdpData[cdp].members, msg.sender);
        uint availBite = availBite(cdp, index);
        require(dart <= availBite, "bite: debt-too-small");

        cdpData[cdp].bite[index] = add(cdpData[cdp].bite[index], dart);

        uint radBefore = vat.dai(address(this));
        uint dink = man.bite(cdp, dart);
        uint radAfter = vat.dai(address(this));

        // update user rad
        rad[msg.sender] = sub(rad[msg.sender],sub(radBefore,radAfter));

        uint userInk = mul(dink,shrn) / shrd;
        dMemberInk = sub(dink,userInk);

        require(dMemberInk >= minInk, "bite: low-dink");

        bytes32 ilk = man.ilks(cdp);

        vat.flux(ilk, address(this), jar, userInk);
        vat.flux(ilk, address(this), msg.sender, dMemberInk);
    }

    function availBite(uint cdp, address member) public view returns (uint) {
        uint index = getIndex(cdpData[cdp].members, member);
        return availBite(cdp, index);
    }

    function availBite(uint cdp, uint index) internal view returns (uint) {
        if(index == uint(-1)) return 0;

        uint numMembers = cdpData[cdp].members.length;

        uint maxArt = cdpData[cdp].art / numMembers;
        // give dust to first member
        if(index == 0) {
            uint dust = cdpData[cdp].art % numMembers;
            maxArt = add(maxArt, dust);
        }
        uint availArt = sub(maxArt, cdpData[cdp].bite[index]);
        
        return availArt;
    }
}
