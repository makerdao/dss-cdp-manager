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

contract VatLike {
    function urns(bytes32, bytes32) public view returns (uint, uint);
    function frob(bytes32, bytes32, bytes32, bytes32, int, int) public;
    function fork(bytes32, bytes32, bytes32, int, int) public;
}

contract JoinLike {
    function exit(bytes32, address, uint) public;
}

contract GetCdps {
    function getCdps(address manager, address guy) external view returns (uint[] memory ids, bytes32[] memory ilks) {
        ids = new uint[](DssCdpManager(manager).count(guy));
        ilks = new bytes32[](DssCdpManager(manager).count(guy));
        uint i = 0;
        uint cdp = DssCdpManager(manager).last(guy);

        while (cdp > 0) {
            ids[i] = cdp;
            ilks[i] = DssCdpManager(manager).ilks(cdp);
            (cdp,) = DssCdpManager(manager).cdps(cdp);
            i++;
        }
    }
}

contract DssCdpManager {
    uint96 public cdpi; // Auto incrementing CDP id
    mapping (uint => Cdp) public cdps; // CDPs linked list (id => data)
    mapping (uint => address) public lads; // CDP owners (id => owner)
    mapping (uint => bytes32) public ilks; // Ilk used by a CDP (id => ilk)

    mapping (address => uint) public last; // Last Cdp from user (owner => id)
    mapping (address => uint) public count; // Amount Cdps from user (owner => amount)

    mapping (address => mapping (uint => mapping (address => bool))) public allows; // Allowance from owner + cdpId to another user

    struct Cdp {
        uint prev;
        uint next;
    }

    event NewCdp(address indexed guy, address indexed lad, uint cdp);

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
        uint cdp
    ) {
        require(msg.sender == lads[cdp] || allows[lads[cdp]][cdp][msg.sender], "not-allowed");
        _;
    }

    function allow(
        uint cdp,
        address guy,
        bool ok
    ) public {
        allows[msg.sender][cdp][guy] = ok;
    }

    function open(bytes32 ilk) public returns (uint cdp) {
        cdp = open(ilk, msg.sender);
    }

    function open(
        bytes32 ilk,
        address guy
    ) public note returns (uint) {
        cdpi++;
        require(uint96(cdpi) > 0, "cdpi-overflow");
        lads[cdpi] = guy;
        ilks[cdpi] = ilk;

        // Add new CDP to double linked list
        if (last[guy] != 0) {
            cdps[cdpi].prev = last[guy];
            cdps[last[guy]].next = cdpi;
        }
        last[guy] = cdpi;
        count[guy] ++;

        emit NewCdp(msg.sender, guy, cdpi);
        return cdpi;
    }

    function move(
        uint cdp,
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
        count[lads[cdp]] --;

        // Transfer ownership
        lads[cdp] = dst;

        // Add transferred CDP to double linked list of destiny user
        cdps[cdp].prev = last[dst];
        cdps[cdp].next = 0;
        cdps[last[dst]].next = cdp;
        last[dst] = cdp;
        count[dst] ++;
    }

    function getUrn(
        uint cdp
    ) public view returns (bytes32 urn) {
        urn = bytes32(uint(address(this)) * 2 ** (12 * 8) + uint96(cdp));
    }

    function exit(
        address join,
        uint cdp,
        address guy,
        uint wad
    ) public note isAllowed(cdp) {
        JoinLike(join).exit(getUrn(cdp), guy, wad);
    }

    function frob(
        address vat,
        uint cdp,
        int dink,
        int dart
    ) public note isAllowed(cdp) {
        bytes32 urn = getUrn(cdp);
        VatLike(vat).frob(
            ilks[cdp],
            urn,
            urn,
            urn,
            dink,
            dart
        );
    }

    function quit(
        address vat,
        uint cdp,
        bytes32 dst
    ) public note isAllowed(cdp) {
        bytes32 urn = getUrn(cdp);
        (uint ink, uint art) = VatLike(vat).urns(ilks[cdp], urn);
        VatLike(vat).fork(
            ilks[cdp],
            urn,
            dst,
            int(ink),
            int(art)
        );
    }
}
