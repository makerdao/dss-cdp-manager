pragma solidity ^0.5.12;

import { DSAuth } from "ds-auth/auth.sol";

interface OSMLike {
    function peep() external view returns (bytes32, bool);
}

interface Spotty {
    function ilks(bytes32) external view returns (
        PipLike pip,
        uint256 mat
    );
}

interface PipLike {
    function read() external view returns (bytes32);
}

interface EndLike {
    function spot() external view returns (Spotty);

}

contract OSMConnector is DSAuth {

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

    function revoke(address addr) external auth {
        authorized[addr] = false;
    }

    function peep() external returns (bytes32, bool) {
        require(authorized[msg.sender], "!authorized");
        return osm.peep(); 
    }

    function read(bytes32 ilk) external returns (bytes32) {
        (PipLike pip,) = end.spot().ilks(ilk);
        return pip.read();
    }
}