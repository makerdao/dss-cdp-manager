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

contract JoinLike {
    function exit(bytes32, address, uint) public;
}

contract DssCdpManager {
    mapping (bytes12 => address) public cdpOwners;
    mapping (address => mapping (bytes12 => mapping (address => bool))) public allows;
    uint96 public cdpi;
    mapping (address => bytes12) public lastCdp;
    mapping (address => uint) public totalCdps;
    mapping (bytes12 => Cdp) public cdps;

    struct Cdp {
        bytes12 prev;
        bytes12 next;
    }

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
        require(msg.sender == cdpOwners[cdp] || allows[cdpOwners[cdp]][cdp][msg.sender], "not-allowed");
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
        require(cdpi > 0, "cdpi-overflow");
        cdp = bytes12(cdpi);
        cdpOwners[cdp] = guy;

        // Add new CDP to double linked list
        cdps[cdp].prev = lastCdp[guy];
        cdps[lastCdp[guy]].next = cdp;
        lastCdp[guy] = cdp;
        totalCdps[guy] ++;

        emit NewCdp(msg.sender, guy, cdp);
    }

    function move(
        bytes12 cdp,
        address dst
    ) public note isAllowed(cdp) {
        require(cdpOwners[cdp] != dst, "dst-already-owner");

        // Remove transferred CDP from double linked list of origin user
        cdps[cdps[cdp].prev].next = cdps[cdp].next;
        if (cdps[cdp].next != "") {
            cdps[cdps[cdp].next].prev = cdps[cdp].prev;
        } else {
            lastCdp[cdpOwners[cdp]] = cdps[cdp].prev;
        }
        totalCdps[cdpOwners[cdp]] --;

        // Transfer ownership
        cdpOwners[cdp] = dst;

        // Add transferred CDP to double linked list of destiny user
        cdps[cdp].prev = lastCdp[dst];
        cdps[cdp].next = "";
        cdps[lastCdp[dst]].next = cdp;
        lastCdp[dst] = cdp;
        totalCdps[dst] ++;
    }

    function getUrn(
        bytes12 cdp
    ) public view returns (bytes32 urn) {
        urn = bytes32(uint(address(this)) * 2 ** (12 * 8) + uint96(cdp));
    }

    function exit(
        address join,
        bytes12 cdp,
        address guy,
        uint wad
    ) public note isAllowed(cdp) {
        JoinLike(join).exit(getUrn(cdp), guy, wad);
    }

    function frob(
        address pit,
        bytes12 cdp,
        bytes32 ilk,
        int dink,
        int dart
    ) public note isAllowed(cdp) {
        bytes32 urn = getUrn(cdp);
        PitLike(pit).frob(
            ilk,
            urn,
            urn,
            urn,
            dink,
            dart
        );
    }

    function getCdps(address guy) external view returns (bytes12[] memory) {
        bytes12[] memory res = new bytes12[](totalCdps[guy]);
        uint i = 0;
        bytes12 cdp = lastCdp[guy];

        while (cdp != "") {
            res[i] = cdp;
            cdp = cdps[cdp].prev;
            i++;
        }
        return res;
    }
}
