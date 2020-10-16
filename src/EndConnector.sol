pragma solidity ^0.5.12;
import { DSAuth } from "ds-auth/auth.sol";

contract FutureEndLike {
    function cat() public returns(address);
    function dog() public returns(address);
}

contract VatLike {
    function wards(address a) public view returns(uint);
}

contract EndConnector is DSAuth {
    VatLike public vat;
    address public cat;

    constructor(address vat_) public {
        vat = VatLike(vat_);
    }

    event NewCat(address newCat);

    function setCat(address newEnd, bool useCat) public {
        // anyone can set cat, only provided exisiting cat is obselete
        require(vat.wards(cat) == 0, "cat-did-not-change");
        set(newEnd, useCat);
    }

    function setCatAdmin(address newEnd, bool useCat) public auth {
        // let admin override cat (but only with something that is approved by vat)
        set(newEnd, useCat);
    }

    function set(address newEnd, bool useCat) internal {
        require(vat.wards(newEnd) == 1, "end-is-not-authorized");

        if(useCat) cat = FutureEndLike(newEnd).cat();
        else cat = FutureEndLike(newEnd).dog();

        require(cat != address(0));
        require(vat.wards(cat) == 1, "new-cat-is-not-authorized");

        emit NewCat(cat);
    }

}
