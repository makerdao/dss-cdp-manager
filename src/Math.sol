pragma solidity ^0.5.12;


contract Math {
    enum MathError {
        NO_ERROR,
        ERROR
    }
    // --- Math ---
    function add(uint x, int y) internal pure returns (uint z) {
        z = x + uint(y);
        require(y >= 0 || z <= x);
        require(y <= 0 || z >= x);
    }
    function sub(uint x, int y) internal pure returns (uint z) {
        z = x - uint(y);
        require(y <= 0 || z <= x);
        require(y >= 0 || z >= x);
    }
    function mul(uint x, int y) internal pure returns (int z) {
        z = int(x) * y;
        require(int(x) >= 0);
        require(y == 0 || z / y == int(x));
    }
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    uint constant ONE = 10 ** 27;

    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, ONE) / y;
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, y) / ONE;
    }

    function toInt(uint x) internal pure returns (int y) {
        y = int(x);
        require(y >= 0);
    }

    // Math with error code
    function add_(uint x, uint y) internal pure returns (MathError err, uint z) {
        z = x + y;
        if(!(z >= x)) return (MathError.ERROR, 0);

        return (MathError.NO_ERROR, z);
    }

    function add_(uint x, int y) internal pure returns (MathError err, uint z) {
        err = MathError.NO_ERROR;
        z = x + uint(y);
        if(!(y >= 0 || z <= x)) err = MathError.ERROR;
        if(!(y <= 0 || z >= x)) err = MathError.ERROR;
    }

    function sub_(uint x, uint y) internal pure returns (MathError err, uint z) {
        if(!(y <= x)) return (MathError.ERROR, 0);
        z = x - y;

        return (MathError.NO_ERROR, z);
    }

    function mul_(uint x, uint y) internal pure returns (MathError err, uint z) {
        if (x == 0) {
            return (MathError.NO_ERROR, 0);
        }

        z = x * y;
        if(!(z / x == y)) return (MathError.ERROR, 0);

        return (MathError.NO_ERROR, z);
    }
}
