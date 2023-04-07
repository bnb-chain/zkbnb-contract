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
    if (block_size == 1) {
      vk[0] = 787209620964319137928400815580615427712489100096803163039480238774089817431;
      vk[1] = 9416235669655799845991764543255411121111462446504759607155457798694636793526;
      vk[2] = 1359254681561672197459818187236656017111847854835080041489467056994555687784;
      vk[3] = 226858947246722977184406702265685542548781928174233819638241591222412500410;
      vk[4] = 14357719382663363188342775740018269781272072738704693804816019763485331698637;
      vk[5] = 7681942806418230385588196679825391831457620309429886541293765201216895102491;
      vk[6] = 3868096228850343443248792534518393053010960790759852458094671127081317835480;
      vk[7] = 14583113887021024770441105815230385344704899273075378520327009196478894584281;
      vk[8] = 1690426874631353345513283012342147190379005832500852868781288353902698614999;
      vk[9] = 19997999670316304036438964561839151153378191722928397140280865930919124554393;
      vk[10] = 16963364134351494007129634333070553977846089855467617014883868952638317489010;
      vk[11] = 20647604565695743393739720516998566607144560359049833054060595520968317103807;
      vk[12] = 2214416260607021554661276851458804797066571776162756181445836702917262806026;
      vk[13] = 7846319071079841219379057026654165738239804058952369963575266922117576714151;
      return vk;
    } else if (block_size == 10) {
      vk[0] = 21531107319690987242297700992305852669472146103768847318339878563953432838142;
      vk[1] = 3726501083547929767211654185275026900853398166933534506875102361107289459674;
      vk[2] = 13437082467303764696992263775918875358867968336021901281678164874422793285002;
      vk[3] = 12370635239482668373610690285083183225143088142583826268424244406048631305043;
      vk[4] = 17809732967493955271371026277670750697073399057863691328272928446287430652252;
      vk[5] = 7255644119677371418604849499192051322728648050252383317201365641075250428848;
      vk[6] = 3109625563038002386654119174670516215321746606566332974675870302703636451781;
      vk[7] = 4553744925337855990711940581079496127564705827446418438870258845438230379079;
      vk[8] = 15614153961852844371804848166463670387817308383653333947433208865257506876674;
      vk[9] = 13706286690039694107463361900129050798203939365405540265837692486905846945822;
      vk[10] = 4307897930236458724266863723114688971700591865419663830312605786946852613346;
      vk[11] = 15211505788073074165364126389789432961613958866692422281518155446984241610241;
      vk[12] = 15622995054178555027867986494421421637577523652623785770040904673753624050455;
      vk[13] = 2088430298464745170050818023207007859437254451322930412486141161521608839305;
      return vk;
    } else {
      revert("u");
    }
  }

  // gammaABC.length == 4 <=> inputs.length == 1
  function ic(uint16 block_size) internal pure returns (uint256[] memory gammaABC) {
    if (block_size == 1) {
      gammaABC = new uint256[](4);
      gammaABC[0] = 15880578324518949169580517441835381191050276697953802247701372526087676068942;
      gammaABC[1] = 8692190334391241596405689170015762215509063383472281361456068475709342500593;
      gammaABC[2] = 16521178409960366132352445246811087688117925998439226384837010158927895076347;
      gammaABC[3] = 20042331581592867106184939996289825766351021430361344829498268762718288744072;
      return gammaABC;
    } else if (block_size == 10) {
      gammaABC = new uint256[](4);
      gammaABC[0] = 2441752565333878524108473572113235185938735517834916192680411804796069653465;
      gammaABC[1] = 18141572768284830319357786267721327713247709509023564131096693248610481847003;
      gammaABC[2] = 15762723239205037256954837173822969736147417542910747693272757177348847288406;
      gammaABC[3] = 18287255333393347799072098703511999856502446169189141720693478223391154752312;
      return gammaABC;
    } else {
      revert("u");
    }
  }

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
