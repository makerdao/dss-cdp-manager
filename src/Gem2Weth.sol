pragma solidity ^0.5.12;

interface GemJoinLike {
    function exit(address, uint) external;
}

interface VatLike {
    function gem(bytes32 ilk, address user) external view returns(uint);
}

contract Gem2Weth {
    GemJoinLike ethJoin;
    VatLike     vat;
    bytes32     ilk;

    constructor(address _vat, address _ethJoin, bytes32 _ilk) public {
        vat = VatLike(_vat);
        ethJoin = GemJoinLike(_ethJoin);
        ilk = _ilk;
    }

    // callable by anyone
    function ethExit(uint wad, bytes32 ilk) public {
        ethJoin.exit(address(this),wad);
    }

    function ethExit() public {
        ethExit(vat.gem(ilk,address(this)),ilk);
    }
}
