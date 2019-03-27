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
    function urns(bytes32, address) public view returns (uint, uint);
    function hope(address) public;
    function frob(bytes32, address, address, address, int, int) public;
    function fork(bytes32, address, address, int, int) public;
}

contract GetCdps {
    function getCdpsAsc(address manager, address guy) external view returns (uint[] memory ids, address[] memory urns, bytes32[] memory ilks) {
        uint count = DssCdpManager(manager).count(guy);
        ids = new uint[](count);
        urns = new address[](count);
        ilks = new bytes32[](count);
        uint i = 0;
        uint id = DssCdpManager(manager).first(guy);

        while (id > 0) {
            ids[i] = id;
            urns[i] = DssCdpManager(manager).urns(id);
            ilks[i] = DssCdpManager(manager).ilks(id);
            (,id) = DssCdpManager(manager).list(id);
            i++;
        }
    }

    function getCdpsDesc(address manager, address guy) external view returns (uint[] memory ids, address[] memory urns, bytes32[] memory ilks) {
        uint count = DssCdpManager(manager).count(guy);
        ids = new uint[](count);
        urns = new address[](count);
        ilks = new bytes32[](count);
        uint i = 0;
        uint id = DssCdpManager(manager).last(guy);

        while (id > 0) {
            ids[i] = id;
            urns[i] = DssCdpManager(manager).urns(id);
            ilks[i] = DssCdpManager(manager).ilks(id);
            (id,) = DssCdpManager(manager).list(id);
            i++;
        }
    }
}

contract UrnHandler {
    constructor(address vat) public {
        VatLike(vat).hope(msg.sender);
    }
}

contract DssCdpManager {
    address                   public vat;
    uint                      public cdpi;      // Auto incremental
    mapping (uint => address) public urns;      // CDPId => UrnHandler
    mapping (uint => List)    public list;      // CDPId => Prev & Next CDPIds (double linked list)
    mapping (uint => address) public lads;      // CDPId => Owner
    mapping (uint => bytes32) public ilks;      // CDPId => Ilk

    mapping (address => uint) public first;     // Owner => First CDPId
    mapping (address => uint) public last;      // Owner => Last CDPId
    mapping (address => uint) public count;     // Owner => Amount of CDPs

    mapping (
        address => mapping (
            uint => mapping (
                address => bool
            )
        )
    ) public allows;                            // Owner => CDPId => Allowed Addr => True/False

    struct List {
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

    constructor(address vat_) public {
        vat = vat_;
    }

    function toInt(uint x) internal pure returns (int y) {
        y = int(x);
        require(y >= 0, "int-overflow");
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
        require(cdpi > 0, "cdpi-overflow");
        urns[cdpi] = address(new UrnHandler(vat));
        lads[cdpi] = guy;
        ilks[cdpi] = ilk;

        // Add new CDP to double linked list and pointers
        if (first[guy] == 0) {
            first[guy] = cdpi;
        }
        if (last[guy] != 0) {
            list[cdpi].prev = last[guy];
            list[last[guy]].next = cdpi;
        }
        last[guy] = cdpi;
        count[guy] ++;

        emit NewCdp(msg.sender, guy, cdpi);
        return cdpi;
    }

    function give(
        uint cdp,
        address dst
    ) public note isAllowed(cdp) {
        require(lads[cdp] != dst, "dst-already-owner");

        // Remove transferred CDP from double linked list of origin user and pointers
        list[list[cdp].prev].next = list[cdp].next;             // Set the next pointer of the prev cdp to the next of the transferred one
        if (list[cdp].next != 0) {                              // If wasn't the last one
            list[list[cdp].next].prev = list[cdp].prev;         // Set the prev pointer of the next cdp to the prev of the transferred one
        } else {                                                // If was the last one
            last[lads[cdp]] = list[cdp].prev;                   // Update last pointer of the owner
        }
        if (first[lads[cdp]] == cdp) {                          // If was the first one
            first[lads[cdp]] = list[cdp].next;                  // Update first pointer of the owner
        }
        count[lads[cdp]] --;

        // Transfer ownership
        lads[cdp] = dst;

        // Add transferred CDP to double linked list of destiny user and pointers
        list[cdp].prev = last[dst];
        list[cdp].next = 0;
        list[last[dst]].next = cdp;
        if (first[dst] == 0) {
            first[dst] = cdp;
        }
        last[dst] = cdp;
        count[dst] ++;
    }

    function frob(
        uint cdp,
        address dst,
        int dink,
        int dart
    ) public note isAllowed(cdp) {
        address urn = urns[cdp];
        VatLike(vat).frob(
            ilks[cdp],
            urn,
            dink >= 0 ? urn : dst,
            dart <= 0 ? urn : dst,
            dink,
            dart
        );
    }

    function quit(
        uint cdp,
        address dst
    ) public note isAllowed(cdp) {
        address urn = urns[cdp];
        (uint ink, uint art) = VatLike(vat).urns(ilks[cdp], urn);
        VatLike(vat).fork(
            ilks[cdp],
            urn,
            dst,
            toInt(ink),
            toInt(art)
        );
    }
}
