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
    function vat() public returns (VatLike);
}

contract VatLike {
    function dai(bytes32) public returns (uint);
    function gem(bytes32, bytes32) public returns (uint);
}

contract Move {
    function move(bytes32, bytes32, uint) public;
    function ilk() public view returns (bytes32);
}

contract DssCdpManager {
    mapping (bytes32 => mapping (bytes12 => address)) public cdps;
    mapping (address => mapping (address => bool)) public allows;
    mapping (bytes32 => uint96) public cdpsi;

    uint256 constant ONE = 10 ** 27;

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
        bytes32 ilk,
        bytes12 cdp
    ) {
        require(msg.sender == cdps[ilk][cdp] || allows[cdps[ilk][cdp]][msg.sender], "");
        _;
    }

    function allow(
        address guy,
        bool ok
    ) public {
        allows[msg.sender][guy] = ok;
    }

    function open(
        bytes32 ilk
    ) public returns (bytes12 cdp) {
        cdp = open(ilk, msg.sender);
    }

    function open(
        bytes32 ilk,
        address guy
    ) public note returns (bytes12 cdp) {
        cdpsi[ilk] ++;
        cdp = bytes12(cdpsi[ilk]);
        cdps[ilk][cdp] = guy;
    }

    function move(
        bytes32 ilk,
        bytes12 cdp,
        address dst
    ) public note isAllowed(ilk, cdp) {
        cdps[ilk][cdp] = dst;
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

    function frob(
        address pit,
        address daiMove,
        address gemMove,
        bytes32 ilk,
        bytes12 cdp,
        int dink,
        int dart,
        bytes32 dst
    ) public /*note*/ isAllowed(ilk, cdp) {
        bytes32 urn = getUrn(cdp);
        PitLike(pit).frob(urn, ilk, dink, dart);
        require(Move(gemMove).ilk() == ilk, "wrong-gemMove-contract");
        Move(daiMove).move(urn, dst, PitLike(pit).vat().dai(urn) / ONE);
        Move(gemMove).move(urn, dst, PitLike(pit).vat().gem(ilk, urn) / ONE);
    }
}
