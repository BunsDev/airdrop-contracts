// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

library RpcLookup {
  function getVestingTokenAddress(uint256 _chainId) public pure returns (address) {
    // Mainnets -- N/A

    // Testnets
    if (_chainId == 5) {
      return address(0x6B52aC94d8bca69877c9359dB5905e452E5bB09D);
    }
    if (_chainId == 420) {
      return address(0xc2260A7c3997Be7fA6759B310C38e08F35fCF54A);
    }
    if (_chainId == 80001) {
      return address(0x11ECF3DdD6a903127dde84656EF97A582c4ce490);
    }

    require(false, "!token address for chain");
  }

  function getClawbackAdminEnvName(uint256 _chainId) public pure returns (string memory) {
    // Mainnets
    if (_chainId == 1) {
      return "MAINNET_CLAWBACK_ADMIN";
    }
    if (_chainId == 10) {
      return "OPTIMISM_CLAWBACK_ADMIN";
    }
    if (_chainId == 56) {
      return "BNB_CLAWBACK_ADMIN";
    }
    if (_chainId == 100) {
      return "GNOSIS_CLAWBACK_ADMIN";
    }
    if (_chainId == 137) {
      return "POLYGON_CLAWBACK_ADMIN";
    }
    if (_chainId == 42161) {
      return "ARBITRUM_CLAWBACK_ADMIN";
    }

    // Testnets
    if (_chainId == 5) {
      return "GOERLI_CLAWBACK_ADMIN";
    }
    if (_chainId == 420) {
      return "OPTIMISM_GOERLI_CLAWBACK_ADMIN";
    }
    if (_chainId == 80001) {
      return "MUMBAI_CLAWBACK_ADMIN";
    }
    if (_chainId == 421613) {
      return "ARBITRUM_GOERLI_CLAWBACK_ADMIN";
    }

    require(false, "!rpc env var for chain");
  }
}
