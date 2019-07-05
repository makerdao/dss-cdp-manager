pragma solidity >= 0.5.0;

import "dss/lib.sol";

contract VatLike {
    function urns(bytes32, address) public view returns (uint, uint);
    function hope(address) public;
    function flux(bytes32, address, address, uint) public;
    function move(address, address, uint) public;
    function frob(bytes32, address, address, address, int, int) public;
    function fork(bytes32, address, address, int, int) public;
}

contract UrnHandler {
    constructor(address vat) public {
        VatLike(vat).hope(msg.sender);
    }
}

contract DssCdpManager is DSNote {
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
                address => uint
            )
        )
    ) public allows;                            // Owner => CDPId => Allowed Addr => True/False

    struct List {
        uint prev;
        uint next;
    }

    event NewCdp(address indexed guy, address indexed lad, uint cdp);

    modifier isAllowed(
        uint cdp
    ) {
        require(msg.sender == lads[cdp] || allows[lads[cdp]][cdp][msg.sender] == 1, "not-allowed");
        _;
    }

    constructor(address vat_) public {
        vat = vat_;
    }

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "add-overflow");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "sub-overflow");
    }

    function toInt(uint x) internal pure returns (int y) {
        y = int(x);
        require(y >= 0, "uint-to-int-overflow");
    }

    function allow(
        uint cdp,
        address guy,
        uint ok
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
        cdpi = add(cdpi, 1);
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
        count[guy] = add(count[guy], 1);

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
        count[lads[cdp]] = sub(count[lads[cdp]], 1);

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
        count[dst] = add(count[dst], 1);
    }

    function frob(
        uint cdp,
        int dink,
        int dart
    ) public {
        frob(cdp, urns[cdp], dink, dart);
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

    function flux(
        uint cdp,
        address dst,
        uint wad
    ) public note isAllowed(cdp) {
        VatLike(vat).flux(ilks[cdp], urns[cdp], dst, wad);
    }

    function move(
        uint cdp,
        address dst,
        uint rad
    ) public note isAllowed(cdp) {
        VatLike(vat).move(urns[cdp], dst, rad);
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
