/// DssCdpManager.sol

// Copyright (C) 2018-2019 Rain <rainbreak@riseup.net>
// Copyright (C) 2018-2019 Gonzalo Balabasquer <gbalabasquer@gmail.com>
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
    uint96 public cdpi; // Auto incrementing CDP id
    mapping (bytes12 => Cdp) public cdps; // CDPs linked list (id => data)
    mapping (bytes12 => address) public lads; // CDP owners (id => owner)
    mapping (bytes12 => bytes32) public ilks; // Ilk used by a CDP (id => ilk)

    mapping (address => bytes12) public last; // Last CDP id of a user (owner => id)
    mapping (address => uint) public count; // Amount of CDPs owned by a user (owner => amount)

    mapping (address => mapping (bytes12 => mapping (address => bool))) public allows; // Allowance from owner + CDP id to another user

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
        require(msg.sender == lads[cdp] || allows[lads[cdp]][cdp][msg.sender], "not-allowed");
        _;
    }

    function allow(
        bytes12 cdp,
        address guy,
        bool ok
    ) public {
        allows[msg.sender][cdp][guy] = ok;
    }

    function open(bytes32 ilk) public returns (bytes12 cdp) {
        cdp = open(ilk, msg.sender);
    }

    function open(
        bytes32 ilk,
        address guy
    ) public note returns (bytes12 cdp) {
        cdpi++;
        require(cdpi > 0, "cdpi-overflow");
        cdp = bytes12(cdpi);
        lads[cdp] = guy;
        ilks[cdp] = ilk;

        // Add new CDP to double linked list
        if (last[guy] != 0) {
            cdps[cdp].prev = last[guy];
            cdps[last[guy]].next = cdp;
        }
        last[guy] = cdp;
        count[guy]++;

        emit NewCdp(msg.sender, guy, cdp);
    }

    function move(
        bytes12 cdp,
        address dst
    ) public note isAllowed(cdp) {
        require(lads[cdp] != dst, "dst-already-owner");

        // Remove transferred CDP from double linked list of origin user
        cdps[cdps[cdp].prev].next = cdps[cdp].next;
        if (cdps[cdp].next != 0) {
            cdps[cdps[cdp].next].prev = cdps[cdp].prev;
        } else {
            last[lads[cdp]] = cdps[cdp].prev;
        }
        count[lads[cdp]]--;

        // Transfer ownership
        lads[cdp] = dst;

        // Add transferred CDP to double linked list of destiny user
        cdps[cdp].prev = last[dst];
        cdps[cdp].next = 0;
        cdps[last[dst]].next = cdp;
        last[dst] = cdp;
        count[dst]++;
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
        require(ilks[cdp] == ilk, "incorrect-ilk-for-cdp");
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

    function getCdps(address guy) external view returns (bytes32[] memory) {
        bytes32[] memory res = new bytes32[](count[guy] * 2);
        uint i = 0;
        bytes12 cdp = last[guy];

        while (cdp != 0) {
            res[i] = bytes32(cdp);
            res[i + 1] = ilks[cdp];
            cdp = cdps[cdp].prev;
            i += 2;
        }
        return res;
    }
}
