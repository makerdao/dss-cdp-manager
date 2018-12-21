/// DssCdpManager.sol

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
// Copyright (C) 2018 Gonzalo Balabasquer <gbalabasquer@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >= 0.5.0;

contract PitLike {
    function frob(bytes32, bytes32, bytes32, bytes32, int256, int256) public;
}

contract Adapter {
    function exit(bytes32, address, uint) public;
}

contract DssCdpManager {
    mapping (bytes12 => address) public cdps;
    mapping (address => mapping (bytes12 => mapping (address => bool))) public allows;
    uint96 public cdpi;

    event NewCdp(address indexed guy, address indexed lad, bytes12 cdp);

    event Note(
        bytes4   indexed  sig,
        bytes32  indexed  foo,
        bytes32  indexed  bar,
        bytes32  indexed  too,
        bytes             fax
    ) anonymous;

    modifier note {
        bytes32 foo;
        bytes32 bar;
        bytes32 too;
        assembly {
            foo := calldataload(4)
            bar := calldataload(36)
            too := calldataload(68)
        }
        emit Note(msg.sig, foo, bar, too, msg.data);
        _;
    }

    modifier isAllowed(
        bytes12 cdp
    ) {
        require(msg.sender == cdps[cdp] || allows[cdps[cdp]][cdp][msg.sender], "not-allowed");
        _;
    }

    function allow(
        bytes12 cdp,
        address guy,
        bool ok
    ) public {
        allows[msg.sender][cdp][guy] = ok;
    }

    function open() public returns (bytes12 cdp) {
        cdp = open(msg.sender);
    }

    function open(
        address guy
    ) public note returns (bytes12 cdp) {
        cdpi ++;
        cdp = bytes12(cdpi);
        cdps[cdp] = guy;
        emit NewCdp(msg.sender, guy, cdp);
    }

    function move(
        bytes12 cdp,
        address dst
    ) public note isAllowed(cdp) {
        cdps[cdp] = dst;
    }

    function getUrn(
        bytes12 cdp
    ) public view returns (bytes32 urn) {
        urn = bytes32(uint(address(this)) * 2 ** (12 * 8) + uint96(cdp));
    }

    function frob(
        address pit,
        bytes12 cdp,
        bytes32 ilk,
        bytes32 dst,
        int dink,
        int dart
    ) public note isAllowed(cdp) {
        bytes32 urn = getUrn(cdp);
        PitLike(pit).frob(
            ilk,
            urn,
            dink >= 0 ? urn : dst,
            dart <= 0 ? urn : dst,
            dink,
            dart
        );
    }
}
