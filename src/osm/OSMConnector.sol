pragma solidity ^0.5.12;

import { DSAuth } from "ds-auth/auth.sol";

interface OSMLike {
    function bud(address) external view returns (uint);
    function peep() external view returns (bytes32, bool);
}

contract OSMConnector is DSAuth {

    mapping(address => bool) public authorized;
    OSMLike public osm;

    constructor(OSMLike osm_, address medianizer_) public {
        osm = osm_;
    }

    function authorize(address addr) external auth {
        authorized[addr] = true;
    }

    function revoke(address addr) external auth {
        authorized[addr] = false;
    }

    function peep() external returns (uint price) {
        require(authorized[msg.sender] && osm.bud(address(this)) == 1, "!allowed");
        (bytes32 val,) = osm.peep(); 
        price = uint(val);
    }
}