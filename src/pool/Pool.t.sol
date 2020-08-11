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
        pool.setIlk("ETH",true);

        member = members[0];
    }

    function getMembers() internal view returns(address[] memory) {
        address[] memory memoryMembers = new address[](members.length);
        for(uint i = 0 ; i < members.length ; i++) {
            memoryMembers[i] = address(members[i]);
        }

        return memoryMembers;
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

    // 2 out of 4 are selected
    function testchooseMembers1() public {
        // sufficient
        members[0].doDeposit(pool,1000);
        members[2].doDeposit(pool,950);

        // insufficient
        members[1].doDeposit(pool,100);
        members[3].doDeposit(pool,95);

        address[] memory winners = pool.chooseMembers(404,getMembers());
        assertEq(winners.length, 2);
        assertEq(winners[0], address(members[0]));
        assertEq(winners[1], address(members[2]));
    }

    // 2 out of 4 are selected, third user has enough when divided by 4, but not by 3.
    function testchooseMembers2() public {
        // sufficient
        members[1].doDeposit(pool,1000);
        members[3].doDeposit(pool,950);

        // insufficient
        members[0].doDeposit(pool,110);
        members[2].doDeposit(pool,95);

        address[] memory winners = pool.chooseMembers(400,getMembers());
        assertEq(winners.length, 2);
        assertEq(winners[0], address(members[1]));
        assertEq(winners[1], address(members[3]));
    }

    // all are selected
    function testchooseMembers3() public {
        // sufficient
        members[0].doDeposit(pool,1000);
        members[1].doDeposit(pool,950);
        members[2].doDeposit(pool,850);
        members[3].doDeposit(pool,750);

        address[] memory winners = pool.chooseMembers(400,getMembers());
        assertEq(winners.length, 4);
        assertEq(winners[0], address(members[0]));
        assertEq(winners[1], address(members[1]));
        assertEq(winners[2], address(members[2]));
        assertEq(winners[3], address(members[3]));
    }

    // none are selected
    function testchooseMembers4() public {
        // insufficient
        members[0].doDeposit(pool,99);
        members[1].doDeposit(pool,399);
        members[2].doDeposit(pool,101);
        members[3].doDeposit(pool,199);

        address[] memory winners = pool.chooseMembers(400,getMembers());
        assertEq(winners.length, 0);
    }

    // test all possibilities
    function testchooseMembers5() public {
        uint rad = 1000;
        for(uint i = 0 ; i < 16 ; i++) {
            uint expectedNum = 0;
            if(i & 0x1 > 0) expectedNum++;
            if(i & 0x2 > 0) expectedNum++;
            if(i & 0x4 > 0) expectedNum++;
            if(i & 0x8 > 0) expectedNum++;

            address[] memory expectedWinners = new address[](expectedNum);
            uint assignedWinners = 0;

            for(uint j = 0 ; j < members.length ; j++) {
                members[j].doWithdraw(pool, pool.rad(address(members[j])));
                if((i >> j) & 0x1 > 0) {
                    members[j].doDeposit(pool,1 + rad/expectedNum);
                    expectedWinners[assignedWinners++] = address(members[j]);
                }
                else members[j].doDeposit(pool,rad/members.length - 1);
            }

            address[] memory winners = pool.chooseMembers(rad,getMembers());
            assertEq(winners.length, expectedNum);
            for(uint k = 0 ; k < winners.length ; k++) {
                assertEq(winners[k],expectedWinners[k]);
            }
        }
    }

    function testSetIlk() public {
        pool.setIlk("ETH-A",true);
        assert(pool.ilks("ETH-A") == true);
        pool.setIlk("ETH-A",false);
        assert(pool.ilks("ETH-A") == false);

        pool.setIlk("ETH-B",false);
        pool.setIlk("ETH-C",true);
        pool.setIlk("ETH-D",false);
        pool.setIlk("ETH-E",true);

        assert(pool.ilks("ETH-B") == false);
        assert(pool.ilks("ETH-C") == true);
        assert(pool.ilks("ETH-D") == false);
        assert(pool.ilks("ETH-E") == true);
    }

    function testchooseMember1() public {
        // sufficient
        members[2].doDeposit(pool,1000);

        address[] memory winners = pool.chooseMember(0,404,getMembers());
        assertEq(winners.length, 1);
        assertEq(winners[0], address(members[2]));
    }

    function testchooseMember2() public {
        // sufficient
        members[0].doDeposit(pool,1000);
        members[1].doDeposit(pool,1000);
        members[2].doDeposit(pool,1000);
        members[3].doDeposit(pool,1000);

        bool one = true; bool two = true; bool three = true; bool four = true;
        uint maxNumIter = 1000;

        timeReset();
        while(one || two || three || four) {
            assert(maxNumIter-- > 0);

            address[] memory winners = pool.chooseMember(0,404,getMembers());
            assertEq(winners.length, 1);
            if(winners[0] == address(members[0])) one = false;
            if(winners[0] == address(members[1])) two = false;
            if(winners[0] == address(members[2])) three = false;
            if(winners[0] == address(members[3])) four = false;

            forwardTime(23 minutes);
        }
    }
}
