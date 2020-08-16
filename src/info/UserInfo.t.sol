pragma solidity ^0.5.12;
//pragma experimental ABIEncoderV2;

import {Vat, Spotter} from "dss-deploy/DssDeploy.t.base.sol";
import {BCdpManagerTestBase, Hevm, FakeUser} from "./../BCdpManager.t.sol";
import {BCdpManager} from "./../BCdpManager.sol";
import {DssCdpManager} from "./../DssCdpManager.sol";
import {GetCdps} from "./../GetCdps.sol";
import {UserInfo, VatLike,DSProxyLike,ProxyRegistryLike,SpotLike} from "./UserInfo.sol";


contract FakeProxy is FakeUser {
    address public owner;
    function setOwner(address newOwner) public {
        owner = newOwner;
    }

    function execute(address _target, bytes memory _data)
        public
        payable
        returns (bytes32 response)
    {
        // call contract in current context
        assembly {
            let succeeded := delegatecall(sub(gas, 5000), _target, add(_data, 0x20), mload(_data), 0, 32)
            response := mload(0)      // load delegatecall output
            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                revert(0, 0)
            }
        }
    }
}

contract FakeRegistry {
      mapping(address=>FakeProxy) public proxies;

      function build() public returns(FakeProxy){
          proxies[msg.sender] = new FakeProxy();
          proxies[msg.sender].setOwner(msg.sender);

          return proxies[msg.sender];
      }
}

contract UserInfoTest is BCdpManagerTestBase {
    DssCdpManager dsManager;
    GetCdps       getCdps;
    FakeRegistry  registry;
    UserInfo      userInfo;

    VatLike vatLike;
    ProxyRegistryLike registryLike;
    SpotLike spotterLike;

    function setUp() public {

        super.setUp();

        dsManager = new DssCdpManager(address(vat));
        getCdps = new GetCdps();
        registry = new FakeRegistry();
        userInfo = new UserInfo();

        vatLike = VatLike(address(vat));
        registryLike = ProxyRegistryLike(address(registry));
        spotterLike = SpotLike(address(spotter));
    }

    function openCdp(address man, uint ink,uint art) internal returns(uint){
        uint cdp = DssCdpManager(man).open("ETH", address(this));

        weth.deposit.value(ink)();
        weth.approve(address(ethJoin), ink);
        ethJoin.join(DssCdpManager(man).urns(cdp), ink);

        DssCdpManager(man).frob(cdp, int(ink), int(art));

        return cdp;
    }

    function timeReset() internal {
        hevm.warp(now);
    }

    function forwardTime(uint deltaInSec) internal {
        hevm.warp(now + deltaInSec);
    }

    function testProxyInfo() public {
        FakeProxy proxy = registry.build();
        userInfo.setInfo(address(this), "ETH", manager, dsManager,getCdps,vatLike,
                         spotterLike, registryLike, address(123));
        assertEq(userInfo.hasProxy() ? uint(1) : uint(0),uint(1));
        assertEq(address(userInfo.userProxy()),address(proxy));
        assert(! userInfo.hasCdp());
        assert(! userInfo.makerdaoHasCdp());
    }

    function testNoProxy() public {
        userInfo.setInfo(address(this), "ETH", manager, dsManager,getCdps,vatLike,
                         spotterLike, registryLike, address(123));
        assertEq(userInfo.hasProxy() ? uint(1) : uint(0),uint(0));
        assertEq(address(userInfo.userProxy()),address(0));
    }

    function testBCdp() public {
        FakeProxy proxy = registry.build();
        uint bCdp = openCdp(address(manager),1 ether, 20 ether);
        manager.give(bCdp,address(proxy));
        userInfo.setInfo(address(this), "ETH", manager, dsManager,getCdps,vatLike,
                         spotterLike, registryLike, address(123));
        assertEq(userInfo.hasProxy() ? uint(1) : uint(0),uint(1));
        assertEq(address(userInfo.userProxy()),address(proxy));
        assertEq(userInfo.cdp(),bCdp);
        assert(userInfo.hasCdp());
        assertEq(userInfo.ethDeposit(),1 ether);
        assertEq(userInfo.daiDebt(),20 ether);
        assertEq(userInfo.maxDaiDebt(),200 ether); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(),300e18);
        assert(! userInfo.makerdaoHasCdp());
    }

    function testMakerDaoCdp() public {
        FakeProxy proxy = registry.build();
        uint bCdp = openCdp(address(dsManager),1 ether, 20 ether);
        dsManager.give(bCdp,address(proxy));
        userInfo.setInfo(address(this), "ETH", manager, dsManager,getCdps,vatLike,
                         spotterLike, registryLike, address(123));
        assertEq(userInfo.hasProxy() ? uint(1) : uint(0),uint(1));
        assertEq(address(userInfo.userProxy()),address(proxy));
        assertEq(userInfo.makerdaoCdp(),bCdp);
        assert(userInfo.makerdaoHasCdp());
        assertEq(userInfo.makerdaoEthDeposit(),1 ether);
        assertEq(userInfo.makerdaoDaiDebt(),20 ether);
        assertEq(userInfo.makerdaoMaxDaiDebt(),200 ether); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(),300e18);
        assert(! userInfo.hasCdp());
    }

    function testBothHaveCdp() public {
        FakeProxy proxy = registry.build();
        uint bCdp = openCdp(address(manager),1 ether, 20 ether);
        uint mCdp = openCdp(address(dsManager),2 ether, 30 ether);
        manager.give(bCdp,address(proxy));
        dsManager.give(mCdp,address(proxy));
        userInfo.setInfo(address(this), "ETH", manager, dsManager,getCdps,vatLike,
                         spotterLike, registryLike, address(123));

        assertEq(userInfo.hasProxy() ? uint(1) : uint(0),uint(1));
        assertEq(address(userInfo.userProxy()),address(proxy));
        assertEq(userInfo.cdp(),bCdp);
        assert(userInfo.hasCdp());
        assertEq(userInfo.ethDeposit(),1 ether);
        assertEq(userInfo.daiDebt(),20 ether);
        assertEq(userInfo.maxDaiDebt(),200 ether); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(),300e18);

        assertEq(userInfo.makerdaoCdp(),mCdp);
        assert(userInfo.makerdaoHasCdp());
        assertEq(userInfo.makerdaoEthDeposit(),2 ether);
        assertEq(userInfo.makerdaoDaiDebt(),30 ether);
        assertEq(userInfo.makerdaoMaxDaiDebt(),400 ether); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(),300e18);
    }

    function testBothHaveCdpWithRate() public {
        FakeProxy proxy = registry.build();
        uint bCdp = openCdp(address(manager),1 ether, 20 ether);
        uint mCdp = openCdp(address(dsManager),2 ether, 30 ether);

        setRateTo1p1();

        manager.give(bCdp,address(proxy));
        dsManager.give(mCdp,address(proxy));
        userInfo.setInfo(address(this), "ETH", manager, dsManager,getCdps,vatLike,
                         spotterLike, registryLike, address(123));

        assertEq(userInfo.hasProxy() ? uint(1) : uint(0),uint(1));
        assertEq(address(userInfo.userProxy()),address(proxy));
        assertEq(userInfo.cdp(),bCdp);
        assert(userInfo.hasCdp());
        assertEq(userInfo.ethDeposit(),1 ether);
        assertEq(userInfo.daiDebt(),22 ether);
        // -1 is a rounding error
        assertEq(userInfo.maxDaiDebt(),200 ether - 1); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(),300e18);

        assertEq(userInfo.makerdaoCdp(),mCdp);
        assert(userInfo.makerdaoHasCdp());
        assertEq(userInfo.makerdaoEthDeposit(),2 ether);
        assertEq(userInfo.makerdaoDaiDebt(),33 ether);
        // -1 is a rounding error
        assertEq(userInfo.makerdaoMaxDaiDebt(),400 ether - 1); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(),300e18);
    }

    function testBothHaveCdpWithRateAndDifferentPrice() public {
        FakeProxy proxy = registry.build();
        uint bCdp = openCdp(address(manager),1 ether, 20 ether);
        uint mCdp = openCdp(address(dsManager),2 ether, 30 ether);

        pipETH.poke(bytes32(uint(123 * 1e18)));
        spotter.poke("ETH");

        setRateTo1p1();

        manager.give(bCdp,address(proxy));
        dsManager.give(mCdp,address(proxy));
        userInfo.setInfo(address(this), "ETH", manager, dsManager,getCdps,vatLike,
                         spotterLike, registryLike, address(123));

        assertEq(userInfo.hasProxy() ? uint(1) : uint(0),uint(1));
        assertEq(address(userInfo.userProxy()),address(proxy));
        assertEq(userInfo.cdp(),bCdp);
        assert(userInfo.hasCdp());
        assertEq(userInfo.ethDeposit(),1 ether);
        assertEq(userInfo.daiDebt(),22 ether);
        // -1 is a rounding error
        assertEq(userInfo.maxDaiDebt(),82 ether - 1); // 150% with spot price of $123
        assertEq(userInfo.spotPrice(),123e18);

        assertEq(userInfo.makerdaoCdp(),mCdp);
        assert(userInfo.makerdaoHasCdp());
        assertEq(userInfo.makerdaoEthDeposit(),2 ether);
        assertEq(userInfo.makerdaoDaiDebt(),33 ether);
        // -1 is a rounding error
        assertEq(userInfo.makerdaoMaxDaiDebt(),164 ether - 1); // 150% with spot price of $123
        assertEq(userInfo.spotPrice(),123e18);
    }

    function setRateTo1p1() internal {
        uint duty;
        uint rho;
        (duty,) = jug.ilks("ETH");
        assertEq(ONE,duty);
        assertEq(uint(address(vat)),uint(address(jug.vat())));
        jug.drip("ETH");
        forwardTime(1);
        jug.drip("ETH");
        this.file(address(jug),"ETH","duty",ONE + ONE/10);
        (duty,) = jug.ilks("ETH");
        assertEq(ONE + ONE / 10,duty);
        forwardTime(1);
        jug.drip("ETH");
        (,rho) = jug.ilks("ETH");
        assertEq(rho,now);
        (,uint rate,,,) = vat.ilks("ETH");
        assertEq(ONE + ONE/10,rate);
    }

    function almostEqual(uint a, uint b) internal returns(bool) {
        assert(a < uint(1) << 200 && b < uint(1) << 200);

        if(a > b) return almostEqual(b,a);
        if(a * (1e6 + 1) < b * 1e6) return false;

        return true;
    }

}
