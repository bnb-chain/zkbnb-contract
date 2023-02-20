// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../interfaces/INFTFactory.sol";
import "../AdditionalZkBNB.sol";

contract AdditionalZkBNBTest is AdditionalZkBNB {
  constructor(address _znsController, address _governanceAddress) {
    znsController = ZNSController(_znsController);
    governance = Governance(_governanceAddress);
  }
}
