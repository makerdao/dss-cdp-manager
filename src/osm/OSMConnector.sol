pragma solidity ^0.5.12;

import { DSAuth } from "ds-auth/auth.sol";

interface OSMLike {
    function peep() external view returns (bytes32, bool);
}

contract OSMConnector is DSAuth {

    mapping(address => bool) public authorized;
    OSMLike public osm;

    constructor(OSMLike osm_) public {
        osm = osm_;
    }

    function authorize(address addr) external auth {
        authorized[addr] = true;
    }

    function revoke(address addr) external auth {
        authorized[addr] = false;
    }

    function peep() external returns (bytes32, bool) {
        require(authorized[msg.sender], "!authorized");
        return osm.peep(); 
    }
}