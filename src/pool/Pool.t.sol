pragma solidity ^0.5.12;

import {BCdpManagerTestBase, Hevm, FakeUser} from "./../BCdpManager.t.sol";
import {BCdpScore} from "./../BCdpScore.sol";
import {Pool} from "./Pool.sol";
import {LiquidationMachine} from "./../LiquidationMachine.sol";


contract FakeMember is FakeUser {
    function doDeposit(Pool pool, uint rad) public {
        pool.deposit(rad);
    }

    function doWithdraw(Pool pool, uint rad) public {
        pool.withdraw(rad);
    }

    function doTopup(Pool pool, uint cdp) public {
        pool.topup(cdp);
    }

    function doUntop(Pool pool, uint cdp) public {
        pool.untop(cdp);
    }

    function doBite(Pool pool, uint cdp, uint dart, uint minInk) public {
        pool.bite(cdp,dart,minInk);
    }
}

contract PoolTest is BCdpManagerTestBase {
    uint currTime;
    FakeMember member;
    FakeMember[] members;
    FakeMember nonMember;
    address constant JAR = address(0x1234567890);

    function setUp() public {
        super.setUp();

        currTime = now;
        hevm.warp(currTime);

        address[] memory memoryMembers = new address[](4);
        for(uint i = 0 ; i < 5 ; i++) {
            FakeMember m = new FakeMember();
            seedMember(m);
            m.doHope(vat,address(pool));

            if(i < 4) {
                members.push(m);
                memoryMembers[i] = address(m);
            }
            else nonMember = m;
        }

        pool.setMembers(memoryMembers);

        member = members[0];
    }

    function openCdp(uint ink,uint art) internal returns(uint){
        uint cdp = manager.open("ETH", address(this));

        weth.deposit.value(ink)();
        weth.approve(address(ethJoin), ink);
        ethJoin.join(manager.urns(cdp), ink);

        manager.frob(cdp, int(ink), int(art));

        return cdp;
    }

    function seedMember(FakeMember m) internal {
        uint cdp = openCdp(1e3 ether, 1e3 ether);
        manager.move(cdp,address(m),1e3 ether * ONE);
    }

    function timeReset() internal {
        currTime = now;
        hevm.warp(currTime);
    }

    function forwardTime(uint deltaInSec) internal {
        currTime += deltaInSec;
        hevm.warp(currTime);
    }

    function testDeposit() public {
        uint userBalance = vat.dai(address(member));
        assertEq(pool.rad(address(member)), 0);
        member.doDeposit(pool,123);
        assertEq(pool.rad(address(member)), 123);
        assertEq(vat.dai(address(member)),userBalance - 123);
    }

    function testFailedDeposit() public {
        nonMember.doDeposit(pool,123);
    }

    function testWithdraw() public {
        uint userBalance = vat.dai(address(member));
        member.doDeposit(pool,123);
        member.doWithdraw(pool,112);
        assertEq(pool.rad(address(member)), 123 - 112);
        assertEq(vat.dai(address(member)),userBalance - 123 + 112);
    }

    function testFailedWithdrawNonMember() public {
        nonMember.doWithdraw(pool,1);
    }

    function testFailedWithdrawInsufficientFunds() public {
        member.doDeposit(pool,123);
        members[1].doDeposit(pool,123);
        member.doWithdraw(pool,123 + 1);
    }
}
