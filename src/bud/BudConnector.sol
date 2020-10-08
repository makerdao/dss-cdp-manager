pragma solidity ^0.5.12;

import { DSAuth } from "ds-auth/auth.sol";

interface OSMLike {
    function peep() external view returns (bytes32, bool);
    function hop()  external view returns(uint16);
    function zzz()  external view returns(uint64);
}

interface Spotty {
    function ilks(bytes32) external view returns (PipLike pip, uint256 mat);
}

interface PipLike {
    function read() external view returns (bytes32);
}

interface EndLike {
    function spot() external view returns (Spotty);
}

contract BudConnector is DSAuth {

    mapping(address => bool) public authorized;
    OSMLike public osm;
    EndLike public end;

    constructor(OSMLike osm_, EndLike end_) public {
        osm = osm_;
        end = end_;
    }

    function authorize(address addr) external auth {
        authorized[addr] = true;
    }

    function peep() external view returns (bytes32, bool) {
        require(authorized[msg.sender], "!authorized");
        return osm.peep(); 
    }

    function read(bytes32 ilk) external view returns (bytes32) {
        require(authorized[msg.sender], "!authorized");
        (PipLike pip,) = end.spot().ilks(ilk);
        return pip.read();
    }

    function hop()  external view returns(uint16) {
        return osm.hop();
    }

    function zzz()  external view returns(uint64) {
        return osm.zzz();
    }
}
