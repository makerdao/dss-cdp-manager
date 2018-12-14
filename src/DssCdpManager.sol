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
    function frob(bytes32, bytes32, int256, int256) public;
}

contract Adapter {
    function exit(bytes32, bytes32, uint) public;
}

contract DssCdpManager {
    mapping (bytes12 => address) public cdps;
    mapping (address => mapping (address => bool)) public allows;
    uint96 public cdpi;

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
        require(msg.sender == cdps[cdp] || allows[cdps[cdp]][msg.sender], "");
        _;
    }

    function allow(
        address guy,
        bool ok
    ) public {
        allows[msg.sender][guy] = ok;
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
        assembly {
            let p := mload(0x40)
            mstore(p, address)
            mstore(p, mload(add(p, 0xc)))
            mstore(add(p, 0x14), cdp)
            urn := mload(p)
        }
    }

    function exit(
        address adapter,
        bytes12 cdp,
        bytes32 guy,
        uint wad
    ) public note isAllowed(cdp) {
        Adapter(adapter).exit(getUrn(cdp), guy, wad);
    }

    function frob(
        address pit,
        bytes12 cdp,
        bytes32 ilk,
        int dink,
        int dart
    ) public note isAllowed(cdp) {
        PitLike(pit).frob(getUrn(cdp), ilk, dink, dart);
    }
}
