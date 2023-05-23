// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

contract ZkBNBVerifier {
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

  function accumulate(
    uint256[] memory in_proof,
    uint256[] memory proof_inputs, // public inputs, length is num_inputs * num_proofs
    uint256 num_proofs
  ) internal view returns (uint256[] memory proofsAandC, uint256[] memory inputAccumulators) {
    uint256 q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 numPublicInputs = proof_inputs.length / num_proofs;
    uint256[] memory entropy = new uint256[](num_proofs);
    inputAccumulators = new uint256[](numPublicInputs + 1);

    for (uint256 proofNumber = 0; proofNumber < num_proofs; ++proofNumber) {
      if (proofNumber == 0) {
        entropy[proofNumber] = 1;
      } else {
        // entropy
        entropy[proofNumber] = getProofEntropy(in_proof, proof_inputs, proofNumber);
      }
      require(entropy[proofNumber] != 0, "Entropy should not be zero");
      // here multiplication by 1 is for a sake of clarity only
      inputAccumulators[0] = addmod(inputAccumulators[0], mulmod(1, entropy[proofNumber], q), q);
      for (uint256 i = 0; i < numPublicInputs; ++i) {
        // TODO
        // require(proof_inputs[proofNumber * numPublicInputs + i] < q, "INVALID_INPUT");
        // accumulate the exponent with extra entropy mod q
        inputAccumulators[i + 1] = addmod(
          inputAccumulators[i + 1],
          mulmod(entropy[proofNumber], proof_inputs[proofNumber * numPublicInputs + i], q),
          q
        );
      }
      // coefficient for +vk.alpha (mind +)
      // accumulators[0] = addmod(accumulators[0], entropy[proofNumber], q); // that's the same as inputAccumulators[0]
    }

    // inputs for scalar multiplication
    uint256[3] memory mul_input;
    bool success;

    // use scalar multiplications to get proof.A[i] * entropy[i]

    proofsAandC = new uint256[](num_proofs * 2 + 2);

    proofsAandC[0] = in_proof[0];
    proofsAandC[1] = in_proof[1];

    for (uint256 proofNumber = 1; proofNumber < num_proofs; ++proofNumber) {
      require(entropy[proofNumber] < q, "INVALID_INPUT");
      mul_input[0] = in_proof[proofNumber * 8];
      mul_input[1] = in_proof[proofNumber * 8 + 1];
      mul_input[2] = entropy[proofNumber];
      assembly {
      // ECMUL, output proofsA[i]
      // success := staticcall(sub(gas(), 2000), 7, mul_input, 0x60, add(add(proofsAandC, 0x20), mul(proofNumber, 0x40)), 0x40)
        success := staticcall(sub(gas(), 2000), 7, mul_input, 0x60, mul_input, 0x40)
      }
      proofsAandC[proofNumber * 2] = mul_input[0];
      proofsAandC[proofNumber * 2 + 1] = mul_input[1];
      require(success, "Failed to call a precompile");
    }

    // use scalar multiplication and addition to get sum(proof.C[i] * entropy[i])

    uint256[4] memory add_input;

    add_input[0] = in_proof[6];
    add_input[1] = in_proof[7];

    for (uint256 proofNumber = 1; proofNumber < num_proofs; ++proofNumber) {
      mul_input[0] = in_proof[proofNumber * 8 + 6];
      mul_input[1] = in_proof[proofNumber * 8 + 7];
      mul_input[2] = entropy[proofNumber];
      assembly {
      // ECMUL, output proofsA
        success := staticcall(sub(gas(), 2000), 7, mul_input, 0x60, add(add_input, 0x40), 0x40)
      }
      require(success, "Failed to call a precompile for G1 multiplication for Proof C");

      assembly {
      // ECADD from two elements that are in add_input and output into first two elements of add_input
        success := staticcall(sub(gas(), 2000), 6, add_input, 0x80, add_input, 0x40)
      }
      require(success, "Failed to call a precompile for G1 addition for Proof C");
    }

    proofsAandC[num_proofs * 2] = add_input[0];
    proofsAandC[num_proofs * 2 + 1] = add_input[1];
  }

  function prepareBatches(
    uint256[14] memory in_vk,
    uint256[] memory vk_gammaABC,
    uint256[] memory inputAccumulators
  ) internal view returns (uint256[4] memory finalVksAlphaX) {
    // Compute the linear combination vk_x using accumulator
    // First two fields are used as the sum and are initially zero
    uint256[4] memory add_input;
    uint256[3] memory mul_input;
    bool success;

    // Performs a sum(gammaABC[i] * inputAccumulator[i])
    for (uint256 i = 0; i < inputAccumulators.length; ++i) {
      mul_input[0] = vk_gammaABC[2 * i];
      mul_input[1] = vk_gammaABC[2 * i + 1];
      mul_input[2] = inputAccumulators[i];

      assembly {
      // ECMUL, output to the last 2 elements of `add_input`
        success := staticcall(sub(gas(), 2000), 7, mul_input, 0x60, add(add_input, 0x40), 0x40)
      }
      require(success, "Failed to call a precompile for G1 multiplication for input accumulator");

      assembly {
      // ECADD from four elements that are in add_input and output into first two elements of add_input
        success := staticcall(sub(gas(), 2000), 6, add_input, 0x80, add_input, 0x40)
      }
      require(success, "Failed to call a precompile for G1 addition for input accumulator");
    }

    finalVksAlphaX[2] = add_input[0];
    finalVksAlphaX[3] = add_input[1];

    // add one extra memory slot for scalar for multiplication usage
    uint256[3] memory finalVKalpha;
    finalVKalpha[0] = in_vk[0];
    finalVKalpha[1] = in_vk[1];
    finalVKalpha[2] = inputAccumulators[0];

    assembly {
    // ECMUL, output to first 2 elements of finalVKalpha
      success := staticcall(sub(gas(), 2000), 7, finalVKalpha, 0x60, finalVKalpha, 0x40)
    }
    require(success, "Failed to call a precompile for G1 multiplication");
    finalVksAlphaX[0] = finalVKalpha[0];
    finalVksAlphaX[1] = finalVKalpha[1];
  }









    function verifyingKey(uint16 block_size) internal pure returns (uint256[14] memory vk) {
        if (block_size == 8) {
            vk[0] = 8305854464963056459391948831897936802727651030594192533888525504548989973337;
            vk[1] = 11384242170905260809490861661769871565738178116787356891612853616247966330814;
            vk[2] = 10393730513922606732159957091431810392782069284647226700666597182027264959269;
            vk[3] = 17094734177584902518803209142154455013573294957427945919104773398314984483375;
            vk[4] = 1979993950145550557020017172287826839114260105869934025641076394243358025340;
            vk[5] = 14187464715731033463076106671291630646849920629753868311880550174569215880925;
            vk[6] = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
            vk[7] = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
            vk[8] = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
            vk[9] = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
            vk[10] = 21825774767836446777961644081437640688555580521074010182673532942682722376098;
            vk[11] = 12282127225807185474402813096723632574528765328490305165418287300601521358224;
            vk[12] = 1715359428933900767818858552296582372687673998427169536197859557329599235902;
            vk[13] = 2479111251570527648255617396038697874677971979100528121573726186474943244158;
            return vk;
        } else if (block_size == 16) {
            vk[0] = 8305854464963056459391948831897936802727651030594192533888525504548989973337;
            vk[1] = 11384242170905260809490861661769871565738178116787356891612853616247966330814;
            vk[2] = 10393730513922606732159957091431810392782069284647226700666597182027264959269;
            vk[3] = 17094734177584902518803209142154455013573294957427945919104773398314984483375;
            vk[4] = 1979993950145550557020017172287826839114260105869934025641076394243358025340;
            vk[5] = 14187464715731033463076106671291630646849920629753868311880550174569215880925;
            vk[6] = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
            vk[7] = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
            vk[8] = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
            vk[9] = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
            vk[10] = 8042333162989302071653811124177880360297521001313715260693204819875229008291;
            vk[11] = 9245687174270925307991757876605435170986483536960731636051239166246900776348;
            vk[12] = 15157789258347838487058338574979891557070889877972968060262008682114747198582;
            vk[13] = 5876597935415766790572332493037675488154161094646964735438770648485923995703;
            return vk;
        } else if (block_size == 32) {
            vk[0] = 8305854464963056459391948831897936802727651030594192533888525504548989973337;
            vk[1] = 11384242170905260809490861661769871565738178116787356891612853616247966330814;
            vk[2] = 10393730513922606732159957091431810392782069284647226700666597182027264959269;
            vk[3] = 17094734177584902518803209142154455013573294957427945919104773398314984483375;
            vk[4] = 1979993950145550557020017172287826839114260105869934025641076394243358025340;
            vk[5] = 14187464715731033463076106671291630646849920629753868311880550174569215880925;
            vk[6] = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
            vk[7] = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
            vk[8] = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
            vk[9] = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
            vk[10] = 9526921068853388272682935569057812416610094267810794927065204386142750240258;
            vk[11] = 7091413415438778338061538138475046648915265940706489483598752107844611860408;
            vk[12] = 19997195207797504362124145993260037197505894531648392868590288972032640029183;
            vk[13] = 1155084088713107129303808279871596231596800463261887079694833204975583219400;
            return vk;
        } else if (block_size == 64) {
            vk[0] = 8305854464963056459391948831897936802727651030594192533888525504548989973337;
            vk[1] = 11384242170905260809490861661769871565738178116787356891612853616247966330814;
            vk[2] = 10393730513922606732159957091431810392782069284647226700666597182027264959269;
            vk[3] = 17094734177584902518803209142154455013573294957427945919104773398314984483375;
            vk[4] = 1979993950145550557020017172287826839114260105869934025641076394243358025340;
            vk[5] = 14187464715731033463076106671291630646849920629753868311880550174569215880925;
            vk[6] = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
            vk[7] = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
            vk[8] = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
            vk[9] = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
            vk[10] = 8870794058071363896163762254506043815690373362055791589357680862976577755997;
            vk[11] = 15243770654507666968788920446486010685063287146699022335555537975146202579394;
            vk[12] = 10387956005753244715466317250152740274102423011640202306524529909819635266854;
            vk[13] = 6761720970130064686908386701206933865479908678301418235267294742956316480181;
            return vk;
        } else {
            revert("u");
        }
    }

    function ic(uint16 block_size) internal pure returns (uint256[] memory gammaABC) {
        if (block_size == 8) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 9028100362518403160811791632468426242225215160152717275965516071618372731841;
            gammaABC[1] = 602098185115510048266275058863513344271475355766511739200451391438090192304;
            gammaABC[2] = 12021697211496672253849408053276723312617484230196037483156013539876044043201;
            gammaABC[3] = 10190212116787224939498371212631446941115828123771385379000501546575731284318;
            return gammaABC;
        } else if (block_size == 16) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 7210327708701516443089685067919262720961508475757379377292415741703254503108;
            gammaABC[1] = 20527149939975851258696012275629828850160198829654237247815842042926199896893;
            gammaABC[2] = 15723598657095489156389707857522587761125044414986229054445917933986910932735;
            gammaABC[3] = 14553815598854986432945927531705738992414039861424243985961124578171010489142;
            return gammaABC;
        } else if (block_size == 32) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 8618549379956361751617959148837235110636042223222403010798444559967390923744;
            gammaABC[1] = 997765950358802178104211734624037212974697570352254211961594437380011557815;
            gammaABC[2] = 17628989614782793734273267199020883581007255429855659739002937794435000123826;
            gammaABC[3] = 1413301250289494302154729858308934597113048994506698403953418622810421132972;
            return gammaABC;
        } else if (block_size == 64) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 21123239612656261295804827189245724411494671049792542310847432463073500483767;
            gammaABC[1] = 1795730944098070273913243011587983819593016016711978997538860352796774656182;
            gammaABC[2] = 18701752905676839909268711379762620759532736403980286930340141427224658798916;
            gammaABC[3] = 21733202867129726901005449057241959250435950776561301253067390658562221547736;
            return gammaABC;
        } else {
            revert("u");
        }
    }








  // gammaABC.length == 4 <=> inputs.length == 1

  function getProofEntropy(
    uint256[] memory in_proof,
    uint256[] memory proof_inputs,
    uint256 proofNumber
  ) internal pure returns (uint256) {
    // Truncate the least significant 3 bits from the 256bit entropy so it fits the scalar field
    return
    uint256(
      keccak256(
        abi.encodePacked(
          in_proof[proofNumber * 8 + 0],
          in_proof[proofNumber * 8 + 1],
          in_proof[proofNumber * 8 + 2],
          in_proof[proofNumber * 8 + 3],
          in_proof[proofNumber * 8 + 4],
          in_proof[proofNumber * 8 + 5],
          in_proof[proofNumber * 8 + 6],
          in_proof[proofNumber * 8 + 7],
          proof_inputs[proofNumber]
        )
      )
    ) >> 3;
  }

  // original equation
  // e(proof.A, proof.B)*e(-vk.alpha, vk.beta)*e(-vk_x, vk.gamma)*e(-proof.C, vk.delta) == 1
  // accumulation of inputs
  // gammaABC[0] + sum[ gammaABC[i+1]^proof_inputs[i] ]

  function verifyBatchProofs(
    uint256[] memory in_proof, // proof itself, length is 8 * num_proofs
    uint256[] memory proof_inputs, // public inputs, length is num_inputs * num_proofs
    uint256 num_proofs,
    uint16 block_size
  ) public view returns (bool success) {
    if (num_proofs == 1) {
      return verifyProof(in_proof, proof_inputs, block_size);
    }
    uint256[14] memory in_vk = verifyingKey(block_size);
    uint256[] memory vk_gammaABC = ic(block_size);
    require(in_proof.length == 8 * num_proofs, "Invalid proofs length for a batch");
    require(proof_inputs.length % num_proofs == 0, "Invalid inputs length for a batch");
    require(
      ((vk_gammaABC.length / 2) - 1) == proof_inputs.length / num_proofs,
      "Mismatching number of inputs for verifying key"
    );

    // strategy is to accumulate entropy separately for all the "constant" elements
    // (accumulate only for G1, can't in G2) of the pairing equation, as well as input verification key,
    // postpone scalar multiplication as much as possible and check only one equation
    // by using 3+num_proofs pairings only

    uint256[] memory proofsAandC;
    uint256[] memory inputAccumulators;
    (proofsAandC, inputAccumulators) = accumulate(in_proof, proof_inputs, num_proofs);

    uint256[4] memory finalVksAlphaX = prepareBatches(in_vk, vk_gammaABC, inputAccumulators);

    uint256[] memory inputs = new uint256[](6 * num_proofs + 18);
    // first num_proofs pairings e(ProofA, ProofB)
    for (uint256 proofNumber = 0; proofNumber < num_proofs; ++proofNumber) {
      inputs[proofNumber * 6] = proofsAandC[proofNumber * 2];
      inputs[proofNumber * 6 + 1] = proofsAandC[proofNumber * 2 + 1];
      inputs[proofNumber * 6 + 2] = in_proof[proofNumber * 8 + 2];
      inputs[proofNumber * 6 + 3] = in_proof[proofNumber * 8 + 3];
      inputs[proofNumber * 6 + 4] = in_proof[proofNumber * 8 + 4];
      inputs[proofNumber * 6 + 5] = in_proof[proofNumber * 8 + 5];
    }

    // second pairing e(-finalVKaplha, vk.beta)
    inputs[num_proofs * 6] = finalVksAlphaX[0];
    inputs[num_proofs * 6 + 1] = NegateY(finalVksAlphaX[1]);
    inputs[num_proofs * 6 + 2] = in_vk[2];
    inputs[num_proofs * 6 + 3] = in_vk[3];
    inputs[num_proofs * 6 + 4] = in_vk[4];
    inputs[num_proofs * 6 + 5] = in_vk[5];

    // third pairing e(-finalVKx, vk.gamma)
    inputs[num_proofs * 6 + 6] = finalVksAlphaX[2];
    inputs[num_proofs * 6 + 7] = NegateY(finalVksAlphaX[3]);
    inputs[num_proofs * 6 + 8] = in_vk[6];
    inputs[num_proofs * 6 + 9] = in_vk[7];
    inputs[num_proofs * 6 + 10] = in_vk[8];
    inputs[num_proofs * 6 + 11] = in_vk[9];

    // fourth pairing e(-proof.C, finalVKdelta)
    inputs[num_proofs * 6 + 12] = proofsAandC[num_proofs * 2];
    inputs[num_proofs * 6 + 13] = NegateY(proofsAandC[num_proofs * 2 + 1]);
    inputs[num_proofs * 6 + 14] = in_vk[10];
    inputs[num_proofs * 6 + 15] = in_vk[11];
    inputs[num_proofs * 6 + 16] = in_vk[12];
    inputs[num_proofs * 6 + 17] = in_vk[13];

    uint256 inputsLength = inputs.length * 32;
    uint256[1] memory out;
    require(inputsLength % 192 == 0, "Inputs length should be multiple of 192 bytes");

    // return true;
    assembly {
      success := staticcall(sub(gas(), 2000), 8, add(inputs, 0x20), inputsLength, out, 0x20)
    }
    require(success, "Failed to call pairings functions");
    return out[0] == 1;
  }

  function verifyProof(
    uint256[] memory in_proof,
    uint256[] memory proof_inputs,
    uint16 block_size
  ) public view returns (bool) {
    uint256[14] memory in_vk = verifyingKey(block_size);
    uint256[] memory vk_gammaABC = ic(block_size);
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
