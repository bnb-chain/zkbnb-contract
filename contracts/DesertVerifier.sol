// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

contract DesertVerifier {
  enum DesertType {
    Noop,
    ExitAsset,
    ExitNft
  }

  function initialize(bytes calldata) external {}

  /// @notice Verifier contract upgrade. Can be external because Proxy contract intercepts illegal calls of this function.
  /// @param upgradeParameters Encoded representation of upgrade parameters
  function upgrade(bytes calldata upgradeParameters) external {}

  function ScalarField() public pure returns (uint256) {
    return 21888242871839275222246405745257275088548364400416034343698204186575808495617;
  }

  function NegateY(uint256 Y) internal pure returns (uint256) {
    uint256 q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    return q - (Y % q);
  }

  function verifyingKey() internal pure returns (uint256[14] memory vk) {
    vk[0] = 4332282361164897797675311661395815642917995109191125877639027900642369905087;
    vk[1] = 12915330585801744505995416820486647993126118116183412393542485676988967451091;
    vk[2] = 17860995496969555127674265474234450104887710110914926552181198899561228684333;
    vk[3] = 4566870234630447608229406053961781787611601928754981586980030719858216206233;
    vk[4] = 18537902144770205516281248737600399019882402187770060650423584032982915386893;
    vk[5] = 8540160583538870870639361602464065058255039296984079782431552614735552650759;
    vk[6] = 13807336353012580443260123717250702852931145724512070154267416753284007420931;
    vk[7] = 4800490065510923949887014006966892108325330496229982991949524650123880696923;
    vk[8] = 7505803066983338220061834147579084920764207912063867422074941187055377844616;
    vk[9] = 11646201873558741118621284933802498820762140029847474502612660658348362883753;
    vk[10] = 8859981885045358148321205927115930930337546008236789731792835411701566770923;
    vk[11] = 5399739975945993060216793074570285914060274546645684893364780254319516591516;
    vk[12] = 16820147133744285682491834542510503041176406171597133126836277331647814160010;
    vk[13] = 14326571654886908959410100255674142006394529598302641673796312373415903048453;
    return vk;
  }

  function ic() internal pure returns (uint256[] memory gammaABC) {
    gammaABC = new uint256[](4);
    gammaABC[0] = 14649434776748726606114824897549043725345223405947397984566216138147924313946;
    gammaABC[1] = 15694799062460067161648900813794732494784648227126097736137536777281811878724;
    gammaABC[2] = 19562290364503525143391379247361981963058811504784444565069628412576734898396;
    gammaABC[3] = 10486766752947749952521960315870987175617388599899416827646878013322810980893;
    return gammaABC;
  }

  // original equation
  // e(proof.A, proof.B)*e(-vk.alpha, vk.beta)*e(-vk_x, vk.gamma)*e(-proof.C, vk.delta) == 1
  function verifyProof(
    uint256[] memory in_proof, // proof itself, length is 8 * num_proofs
    uint256[1] memory proof_inputs // public inputs, length is num_inputs * num_proofs
  ) public view returns (bool) {
    uint256[14] memory in_vk = verifyingKey();
    uint256[] memory vk_gammaABC = ic();
    require(((vk_gammaABC.length / 2) - 1) == proof_inputs.length);
    require(in_proof.length == 8);
    // Compute the linear combination vk_x
    uint256[3] memory mul_input;
    uint256[4] memory add_input;
    bool success;
    uint256 m = 2;

    // First two fields are used as the sum
    add_input[0] = vk_gammaABC[0];
    add_input[1] = vk_gammaABC[1];

    // uint256 q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Performs a sum of gammaABC[0] + sum[ gammaABC[i+1]^proof_inputs[i] ]
    for (uint256 i = 0; i < proof_inputs.length; ++i) {
      // @dev only for qa test
      //  require(proof_inputs[i] < q, "INVALID_INPUT");
      mul_input[0] = vk_gammaABC[m++];
      mul_input[1] = vk_gammaABC[m++];
      mul_input[2] = proof_inputs[i];

      assembly {
        // ECMUL, output to last 2 elements of `add_input`
        success := staticcall(sub(gas(), 2000), 7, mul_input, 0x80, add(add_input, 0x40), 0x60)
      }
      require(success);

      assembly {
        // ECADD
        success := staticcall(sub(gas(), 2000), 6, add_input, 0xc0, add_input, 0x60)
      }
      require(success);
    }

    uint256[24] memory input = [
      // (proof.A, proof.B)
      in_proof[0],
      in_proof[1], // proof.A   (G1)
      in_proof[2],
      in_proof[3],
      in_proof[4],
      in_proof[5], // proof.B   (G2)
      // (-vk.alpha, vk.beta)
      in_vk[0],
      NegateY(in_vk[1]), // -vk.alpha (G1)
      in_vk[2],
      in_vk[3],
      in_vk[4],
      in_vk[5], // vk.beta   (G2)
      // (-vk_x, vk.gamma)
      add_input[0],
      NegateY(add_input[1]), // -vk_x     (G1)
      in_vk[6],
      in_vk[7],
      in_vk[8],
      in_vk[9], // vk.gamma  (G2)
      // (-proof.C, vk.delta)
      in_proof[6],
      NegateY(in_proof[7]), // -proof.C  (G1)
      in_vk[10],
      in_vk[11],
      in_vk[12],
      in_vk[13] // vk.delta  (G2)
    ];

    uint256[1] memory out;
    assembly {
      success := staticcall(sub(gas(), 2000), 8, input, 768, out, 0x20)
    }
    require(success);
    return out[0] == 1;
  }
}
