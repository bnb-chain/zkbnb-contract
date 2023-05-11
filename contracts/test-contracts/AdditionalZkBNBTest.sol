// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../interfaces/INFTFactory.sol";
import "../AdditionalZkBNB.sol";

contract AdditionalZkBNBTest is AdditionalZkBNB {
  constructor(address _governanceAddress) {
    governance = Governance(_governanceAddress);
  }

  // avoid same bytecode as AdditionalZkBNB
  function nouse() external {}
}
