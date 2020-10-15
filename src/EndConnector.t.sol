pragma solidity ^0.5.12;

import { BCdpManagerTestBase, Hevm, FakeUser } from "./BCdpManager.t.sol";
import { EndConnector } from "./EndConnector.sol";

contract EndConnectorTest is BCdpManagerTestBase {
    EndConnector ec;

    function setUp() public {
        super.setUp();
        ec = new EndConnector(address(vat));
        this.rely(address(vat), address(this));
    }

    function testCurrentEnd() public {
        ec.setCat(address(end), true);
        assertEq(ec.cat(), address(cat));
    }

    function testCat() public {
        MockEnd1 mockEnd1 = new MockEnd1();
        this.rely(address(vat), address(mockEnd1));
        this.rely(address(vat), address(0x1));

        ec.setCat(address(mockEnd1), true);
        assertEq(ec.cat(), address(0x1));
    }

    function testDog() public {
        MockEnd2 mockEnd2 = new MockEnd2();
        this.rely(address(vat), address(mockEnd2));
        this.rely(address(vat), address(0x2));

        ec.setCat(address(mockEnd2), false);
        assertEq(ec.cat(), address(0x2));
    }

    function testFailedLion1() public {
        MockEnd3 mockEnd3 = new MockEnd3();
        this.rely(address(vat), address(mockEnd3));
        this.rely(address(vat), address(0x3));

        ec.setCat(address(mockEnd3), false);
    }

    function testFailedLion2() public {
        MockEnd3 mockEnd3 = new MockEnd3();
        this.rely(address(vat), address(mockEnd3));
        this.rely(address(vat), address(0x3));

        ec.setCat(address(mockEnd3), true);
    }

    function testUpgrade() public {
        testCurrentEnd();
        vat.deny(address(cat));
        testCat();
        vat.deny(address(0x1));
        testDog();
    }

    function testFailedUpgradeWithoutChangeCat() public {
        testCurrentEnd();
        testCat();
    }

    function testFailedUpgradeWithoutChangeDog() public {
        testCurrentEnd();
        testCat();
    }

    function testFailedCatUnAuthNewCat() public {
        MockEnd1 mockEnd1 = new MockEnd1();
        this.rely(address(vat), address(mockEnd1));

        ec.setCat(address(mockEnd1), true);
    }

    function testFailedCatUnAuthEnd() public {
        MockEnd1 mockEnd1 = new MockEnd1();
        this.rely(address(vat), address(0x1));

        ec.setCat(address(mockEnd1), true);
    }

    function testFailedCatUnAuthAll() public {
        MockEnd1 mockEnd1 = new MockEnd1();

        ec.setCat(address(mockEnd1), true);
    }
}


contract MockEnd1 {
    function cat() public returns(address) {
        return address(0x1);
    }
}

contract MockEnd2 {
    function dog() public returns(address) {
        return address(0x2);
    }
}

contract MockEnd3 {
    function lion() public returns(address) {
        return address(0x3);
    }
}
