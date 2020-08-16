pragma solidity ^0.5.12;
//pragma experimental ABIEncoderV2;

import {Vat, Spotter} from "dss-deploy/DssDeploy.t.base.sol";
import {BCdpManagerTestBase, Hevm} from "./../BCdpManager.t.sol";
import {BCdpManager} from "./../BCdpManager.sol";
import {DssCdpManager} from "./../DssCdpManager.sol";
import {GetCdps} from "./../GetCdps.sol";
import {UserInfo, VatLike,DSProxyLike,ProxyRegistryLike,SpotLike} from "./UserInfo.sol";


contract FakeProxy {
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

    function testProxy() public {
        FakeProxy proxy = registry.build();
        userInfo.setInfo(address(this), "ETH", manager, dsManager,getCdps,vatLike,
                         spotterLike, registryLike, address(123));
        assertEq(userInfo.hasProxy() ? uint(1) : uint(0),uint(1));
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
