// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

library Chains {
    uint256 internal constant MAINNET = 1;
    uint256 internal constant ARBITRUM = 42161;
    uint256 internal constant OPTIMISM = 10;
    uint256 internal constant BASE = 8453;
    uint256 internal constant POLYGON = 137;
    uint256 internal constant BNB = 56;
    uint256 internal constant GNOSIS = 100;
    uint256 internal constant AVALANCHE = 43114;

    uint256 internal constant LINEA = 59144;
    uint256 internal constant SCROLL = 534352;
    uint256 internal constant BLAST = 81457;
}

library CCIPSelectors {
    uint256 internal constant MAINNET = 5009297550715157269;
    uint256 internal constant AVALANCHE = 6433500567565415381;
    uint256 internal constant POLYGON = 4051577828743386545;
    uint256 internal constant BNB = 11344663589394136015;
    uint256 internal constant ARBITRUM = 4949039107694359620;
    uint256 internal constant OPTIMISM = 3734403246176062136;
    uint256 internal constant BASE = 15971525489660198786;
    uint256 internal constant GNOSIS = 465200170687744372;

    uint256 internal constant LINEA = 4627098889531055414;
    uint256 internal constant SCROLL = 13204309965629103672;
    uint256 internal constant BLAST = 4411394078118774322;
}
