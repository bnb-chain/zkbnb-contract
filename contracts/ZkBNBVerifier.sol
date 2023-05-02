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
            vk[0] = 5468724299575254081578573049994976829000901519788183864335294980499384685293;
            vk[1] = 1236137896571813660382247705218685106058883989523004155965525949784434532744;
            vk[2] = 17994844821746339742841888231943254638275413602834682232068474221976291884263;
            vk[3] = 13190704493934892440892779979125184531796019409172803584980183533306858963057;
            vk[4] = 17933216923346970618467475706733392463484078301952796952049957473114901862238;
            vk[5] = 6195683590312395009507519061031873743372329432500402336916139860815142064184;
            vk[6] = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
            vk[7] = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
            vk[8] = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
            vk[9] = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
            vk[10] = 1360092432523368194617797972912743956722422541060679476349260866636819962622;
            vk[11] = 17647246243977575467821372726493191594445346548389076518632581209860219582394;
            vk[12] = 10144621529982118697896197201472221080571238012030889551165159544309291623649;
            vk[13] = 8236537048199653663772939583621280882588914399374263120084394915153618806451;
            return vk;
        } else if (block_size == 16) {
            vk[0] = 5468724299575254081578573049994976829000901519788183864335294980499384685293;
            vk[1] = 1236137896571813660382247705218685106058883989523004155965525949784434532744;
            vk[2] = 17994844821746339742841888231943254638275413602834682232068474221976291884263;
            vk[3] = 13190704493934892440892779979125184531796019409172803584980183533306858963057;
            vk[4] = 17933216923346970618467475706733392463484078301952796952049957473114901862238;
            vk[5] = 6195683590312395009507519061031873743372329432500402336916139860815142064184;
            vk[6] = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
            vk[7] = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
            vk[8] = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
            vk[9] = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
            vk[10] = 9859358010342387340368045853328873036323770826139568216975012782738431514622;
            vk[11] = 10666425371465795493366332185934210790066717900671889414786359895586138299614;
            vk[12] = 19356762454160597010162861981135722181896786169828563322938484003542042093038;
            vk[13] = 3749603167950715277265493043292499694222021661493453893601102693812200577135;
            return vk;
        } else if (block_size == 32) {
            vk[0] = 5468724299575254081578573049994976829000901519788183864335294980499384685293;
            vk[1] = 1236137896571813660382247705218685106058883989523004155965525949784434532744;
            vk[2] = 17994844821746339742841888231943254638275413602834682232068474221976291884263;
            vk[3] = 13190704493934892440892779979125184531796019409172803584980183533306858963057;
            vk[4] = 17933216923346970618467475706733392463484078301952796952049957473114901862238;
            vk[5] = 6195683590312395009507519061031873743372329432500402336916139860815142064184;
            vk[6] = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
            vk[7] = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
            vk[8] = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
            vk[9] = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
            vk[10] = 5898811819831483562596434606576665998854741442918559428540669245594407313076;
            vk[11] = 20389827629386564946084855441435545382869706251538228650902223925898929313612;
            vk[12] = 275444119789222173515486732788755117638578121140912283498153268501040844885;
            vk[13] = 77915062056805922459369550422247670939117513833296953883859961720073489643;
            return vk;
        } else if (block_size == 64) {
            vk[0] = 5468724299575254081578573049994976829000901519788183864335294980499384685293;
            vk[1] = 1236137896571813660382247705218685106058883989523004155965525949784434532744;
            vk[2] = 17994844821746339742841888231943254638275413602834682232068474221976291884263;
            vk[3] = 13190704493934892440892779979125184531796019409172803584980183533306858963057;
            vk[4] = 17933216923346970618467475706733392463484078301952796952049957473114901862238;
            vk[5] = 6195683590312395009507519061031873743372329432500402336916139860815142064184;
            vk[6] = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
            vk[7] = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
            vk[8] = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
            vk[9] = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
            vk[10] = 5934753168858745385612293791600743478152195981389618924510311051803320112772;
            vk[11] = 4442261719189585182012572389531677272460013832422295578135198957304250458114;
            vk[12] = 4394508231936563812133779022643007997813263343768824556251211244448913399457;
            vk[13] = 1898824272957302987541988932788569599860229576046293262397135718973123249388;
            return vk;
        } else {
            revert("u");
        }
    }

    function ic(uint16 block_size) internal pure returns (uint256[] memory gammaABC) {
        if (block_size == 8) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 11379265525088749794403234831205041617783828973125636097600212120349043584482;
            gammaABC[1] = 1424256217263763342402201024636797138742565521791810129873618390646174198517;
            gammaABC[2] = 5448040700284466129722609241789968724559998282095410537284468675963058611559;
            gammaABC[3] = 18407055799762664966501741100367000414466379951109611689347872137800264222968;
            return gammaABC;
        } else if (block_size == 16) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 11637521782288764517545102038729491869295053489102111607804308538775571581868;
            gammaABC[1] = 2135509285610633293731844145276803740419065288682246897072899542114443787928;
            gammaABC[2] = 4325386358751876432278329583327707655002843385839866026230097318547329982089;
            gammaABC[3] = 11922767947152549254477665980631278263112037718081704088022078116458347621587;
            return gammaABC;
        } else if (block_size == 32) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 7939739410585581582634164203315366257361636927672953209766479430352898758903;
            gammaABC[1] = 10133937133061389322748805529024042588516014687363355247702628364232786706122;
            gammaABC[2] = 732459698784836829094806939982642122693603170497466662102377251509325692017;
            gammaABC[3] = 10777704064021580300711487103812485309178724133769700746965645211132266886515;
            return gammaABC;
        } else if (block_size == 64) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 9215354985541957961141081670291696776330114367341275896465424553375504629396;
            gammaABC[1] = 15313309824009686785899780761973013388551131224992892592170340922167712281821;
            gammaABC[2] = 1629072377468259496984236034473660911828152071951104921704461012295749915725;
            gammaABC[3] = 6691205828611028046653600919918461186366186779000637266403529910588584718928;
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
