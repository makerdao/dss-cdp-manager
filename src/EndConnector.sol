pragma solidity ^0.5.12;


contract FutureEndLike {
    function cat() public returns(address);
    function dog() public returns(address);
}

contract VatLike {
    function wards(address a) public view returns(uint);
}

contract EndConnector {
    VatLike public vat;
    address public cat;

    constructor(address vat_) public {
        vat = VatLike(vat_);
    }

    event NewCat(address newCat);

    function setCat(address newEnd, bool useCat) public {
        require(vat.wards(cat) == 0, "cat-did-not-change");
        require(vat.wards(newEnd) == 1, "end-is-not-authorized");

        if(useCat) cat = FutureEndLike(newEnd).cat();
        else cat = FutureEndLike(newEnd).dog();

        require(cat != address(0));
        require(vat.wards(cat) == 1, "new-cat-is-not-authorized");

        emit NewCat(cat);
    }
}
