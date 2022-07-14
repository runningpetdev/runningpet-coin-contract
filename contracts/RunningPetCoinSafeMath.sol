pragma solidity >=0.5.0<0.6.0;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library RunningPetCoinSafeMath {
    function sub(uint8 a, uint8 b) internal pure returns (uint8) {
        assert(b <= a);
        return a - b;
    }
}
