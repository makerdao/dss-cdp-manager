pragma solidity ^0.5.12;
pragma experimental ABIEncoderV2;

import {BCdpManager} from "./../BCdpManager.sol";
import {DssCdpManager} from "./../DssCdpManager.sol";
import {GetCdps} from "./../GetCdps.sol";
import {Math} from "./../Math.sol";


contract VatLike {
    function urns(bytes32 ilk, address u) public view returns (uint ink, uint art);
    function ilks(bytes32 ilk) public view returns(uint Art, uint rate, uint spot, uint line, uint dust);
}

contract DSProxyLike {
    function owner() public view returns(address);
}

contract ProxyRegistryLike {
    function proxies(address u) public view returns(DSProxyLike);
}

contract SpotLike {
    function par() external view returns (uint256);
    function ilks(bytes32 ilk) external view returns (address pip, uint mat);
}

// this is just something to help avoiding solidity quirks
contract UserInfoStorage {
    struct ProxyInfo {
        bool hasProxy;
        DSProxyLike userProxy;
    }

    struct CdpInfo {
        bool hasCdp;
        uint cdp;
        uint ethDeposit;
        uint daiDebt; // in wad - not in rad
        uint maxDaiDebt;
    }

    struct UserRatingInfo {
        uint userRating;
        uint userRatingProgressPerSec;
        uint totalRating;
        uint totalRatingProgressPerSec;
        uint jarSize;
    }


    struct UserState {
        ProxyInfo proxyInfo;
        CdpInfo bCdpInfo;
        CdpInfo makerdaoCdpInfo;
        uint spotPrice;
        UserRatingInfo userRatingInfo;
    }

    bool public hasProxy;
    address public userProxy;

    bool public hasCdp;
    uint public cdp;
    uint public ethDeposit;
    uint public daiDebt; // in wad - not in rad
    uint public maxDaiDebt;

    bool public makerdaoHasCdp;
    uint public makerDaoCdp;
    uint public makerDaoEthDeposit;
    uint public makerDaoDaiDebt; // in wad - not in rad
    uint public makerDaoMaxDaiDebt;

    uint public userRating;
    uint public userRatingProgressPerSec;
    uint public totalRating;
    uint public totalRatingProgressPerSec;
    uint public jarSize;

    function set(UserState memory state) public {
        hasProxy = state.proxyInfo.hasProxy;
        userProxy = address(state.proxyInfo.userProxy);

        hasCdp = state.bCdpInfo.hasCdp;
        cdp = state.bCdpInfo.cdp;
        ethDeposit = state.bCdpInfo.ethDeposit;
        daiDebt = state.bCdpInfo.daiDebt;
        maxDaiDebt = state.bCdpInfo.maxDaiDebt;

        makerdaoHasCdp = state.makerdaoCdpInfo.hasCdp;
        makerDaoCdp = state.makerdaoCdpInfo.cdp;
        makerDaoEthDeposit = state.makerdaoCdpInfo.ethDeposit;
        makerDaoDaiDebt = state.makerdaoCdpInfo.daiDebt;
        makerDaoMaxDaiDebt = state.makerdaoCdpInfo.maxDaiDebt;

        userRating = state.userRatingInfo.userRating;
        userRatingProgressPerSec = state.userRatingInfo.userRatingProgressPerSec;
        totalRating = state.userRatingInfo.totalRating;
        totalRatingProgressPerSec = state.userRatingInfo.totalRatingProgressPerSec;
        jarSize= state.userRatingInfo.jarSize;
    }
}

contract UserInfo is Math, UserInfoStorage {


    uint constant ONE = 1e27;

    function getFirstCdp(GetCdps getCdp, address manager, address guy, bytes32 ilk) internal view returns(uint) {
        (uint[] memory ids,, bytes32[] memory ilks) = getCdp.getCdpsAsc(manager, guy);

        for(uint i = 0 ; i < ilks.length ; i++) {
            if(ilks[i] == ilk) return ids[i];
        }

        return 0;
    }

    function artToDaiDebt(VatLike vat, bytes32 ilk, uint art) internal view returns(uint) {
        (,uint rate,,,) = vat.ilks(ilk);
        return mul(rate,art) / ONE;
    }

    function calcMaxDebt(VatLike vat, bytes32 ilk, uint ink) internal view returns(uint) {
        (,uint rate,uint spot,,) = vat.ilks(ilk);
        // mul(art,rate) = mul(ink,spot)

        uint maxArt = mul(ink,spot)/rate;
        return artToDaiDebt(vat,ilk,maxArt);
    }

    function calcSpotPrice(VatLike vat, SpotLike spot, bytes32 ilk) internal view returns(uint) {
        (,,uint spotVal,,) = vat.ilks(ilk);
        (, uint mat) = spot.ilks(ilk);
        uint par = spot.par();

        // spotVal = rdiv(rdiv(mul(uint(peep), uint(10 ** 9)), par), mat);
        uint peep = rmul(rmul(spotVal,mat),par) / uint(1e9);

        return peep;
    }

    function getProxyInfo(ProxyRegistryLike registry,address user) public view returns(ProxyInfo memory info) {
        if(registry.proxies(user) == DSProxyLike(0x0) || registry.proxies(user).owner() != user) return info;

        info.hasProxy = true;
        info.userProxy = registry.proxies(user);
    }

    function getCdpInfo(address guy, address manager, bytes32 ilk, VatLike vat, GetCdps getCdp) public view returns(CdpInfo memory info) {
        info.cdp = getFirstCdp(getCdp,manager,guy,ilk);
        info.hasCdp = info.cdp > 0;
        if(info.hasCdp) {
            (uint ink, uint art) = vat.urns(ilk,DssCdpManager(manager).urns(info.cdp));
            info.ethDeposit = ink;
            info.daiDebt = artToDaiDebt(vat,ilk,art);
            info.maxDaiDebt = calcMaxDebt(vat,ilk,ink);
        }
    }

    function getUserRatingInfo(address guy, address jar) public view returns(UserRatingInfo memory info) {
        // TODO - set real sizes
        jar; // shhhh compiler warning
        info.userRating = 70000e18;
        info.userRatingProgressPerSec = 1e18;
        info.totalRating = info.userRating * 11;
        info.totalRatingProgressPerSec = 13e18;
        info.jarSize = 1e4 * 1e18;
    }

    function setInfo(address user, bytes32 ilk, BCdpManager manager, DssCdpManager makerDAOManager, GetCdps getCdp, VatLike vat,
                     SpotLike spot, ProxyRegistryLike registry, address jar)
                     public {
        UserState memory state;
        if(registry.proxies(user) == DSProxyLike(0x0) || registry.proxies(user).owner() != user) return;// state;

        // fill proxy info
        state.proxyInfo = getProxyInfo(registry,user);

        address guy = address(state.proxyInfo.userProxy);

        // fill bprotocol info
        state.bCdpInfo = getCdpInfo(guy,address(manager),ilk,vat,getCdp);

        // fill makerdao info
        state.makerdaoCdpInfo = getCdpInfo(guy,address(makerDAOManager),ilk,vat,getCdp);

        state.spotPrice = calcSpotPrice(vat,spot,ilk);

        state.userRatingInfo = getUserRatingInfo(guy,jar);

        set(state);
    }

    function getInfo(address user, bytes32 ilk, BCdpManager manager, DssCdpManager makerDAOManager, GetCdps getCdp, VatLike vat,
                     SpotLike spot, ProxyRegistryLike registry, address jar)
                     public returns(UserState memory state) {
        setInfo(user,ilk,manager,makerDAOManager,getCdp,vat,spot,registry,jar);
        return state;
    }
}
