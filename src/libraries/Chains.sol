// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

library Chains {
    uint256 internal constant MAINNET = 1;
    uint256 internal constant ARBITRUM = 42161;
    uint256 internal constant OPTIMISM = 10;
    uint256 internal constant BASE = 8453;
    uint256 internal constant POLYGON = 137;
    uint256 internal constant BNB = 56;
    uint256 internal constant ZKSYNC = 324;
    uint256 internal constant GNOSIS = 100;
    uint256 internal constant AVALANCHE = 43114;

    uint256 internal constant LINEA = 59144;
    uint256 internal constant WEMIX = 1111;
    uint256 internal constant METIS = 1088;
    uint256 internal constant SCROLL = 534352;
    uint256 internal constant MODE = 34443;
    uint256 internal constant KROMA = 255;
    uint256 internal constant CELO = 42220;
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
    uint256 internal constant ZKSYNC = 1562403441176082196;
    uint256 internal constant GNOSIS = 465200170687744372;

    uint256 internal constant LINEA = 4627098889531055414;
    uint256 internal constant WEMIX = 5142893604156789321;
    uint256 internal constant METIS = 8805746078405598895;
    uint256 internal constant SCROLL = 13204309965629103672;
    uint256 internal constant MODE = 7264351850409363825;
    uint256 internal constant KROMA = 3719320017875267166;
    uint256 internal constant CELO = 1346049177634351622;
    uint256 internal constant BLAST = 4411394078118774322;
}
