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
      vk[0] = 15531760793662551682779205453166893666117336399929655680250841069431163147269;
      vk[1] = 12110643777294739727940115394906870012079516001973682856226348705739954774886;
      vk[2] = 3252795188994791058549574787540790935191012611399638249496587248587372253405;
      vk[3] = 8142703046787450073638223896906281301192710917583488571878303996084383841171;
      vk[4] = 183785657712806276197397279448214945770157669701837181846748620799969237145;
      vk[5] = 12553968739533982064302977206386729304168963186282932574813237322835971137249;
      vk[6] = 4656699596813969045545537760589443554873719856984987655266754669411792710538;
      vk[7] = 19485164923730660176739347916786378206882510053289798953304691158206723815873;
      vk[8] = 7772990068351831909001876036128358011451852892943153700127401565071724288732;
      vk[9] = 7619136970817372677823938808307325961294313160693102533286890048941301301695;
      vk[10] = 4650835880354649166248988733910070362454740744083995603923080677787406673333;
      vk[11] = 4178846780328245011585839812905193719045679622470619976510958757282417727498;
      vk[12] = 9512815422159493835510641602729343551020557581699434946971400434583483223629;
      vk[13] = 10393604040523258610940615939652302236096619899006120779336059463822619379440;
      return vk;
    } else if (block_size == 16) {
      vk[0] = 15169416325092065311841812646661434227352138284600998523847947277675447314358;
      vk[1] = 7139584701353980696815263426089649294902863523710964189936629768986556518575;
      vk[2] = 2717034101193701536825469470392753320427392340397675210727876721910612133284;
      vk[3] = 5924406795581602267467906420903010161211698943490568251108502837557320464595;
      vk[4] = 18348842018501870551344170073163641759664660838329990218433390630075393924099;
      vk[5] = 605826485150130328271466993085132332799672441876326508663560093850220496589;
      vk[6] = 10066144580961262502589140242747560941085429681989315962604668395891021063086;
      vk[7] = 3611117328651729473133104588084922667191602076298967147770723580524039450850;
      vk[8] = 9361898447324321619547760550799979016732221915507725478179816072429048225051;
      vk[9] = 10808434777807517289661629300720488633756806134145435343839882723868199806845;
      vk[10] = 3979635621703184259149571792876768583402909888446740759126010399708500748649;
      vk[11] = 19688465758702265910587757638716416592337632220434699809828257759506941438512;
      vk[12] = 4192294988466677403574809789956486704600565501671217970770735766211978021013;
      vk[13] = 1887670827790376798397328431138935431485056440810310817614635133695328369436;
      return vk;
    } else if (block_size == 32) {
      vk[0] = 4814254994421822994535759520352316856494492242202618992896469323220744525696;
      vk[1] = 7557600979876319366556426448764702613700684139535868426161337086757986140767;
      vk[2] = 465184649747423629381676107740611016756706872421344025042491384199110217584;
      vk[3] = 1270901148151304852481179718734813918062547664157331206870201013551435011960;
      vk[4] = 6924161983037471717948026178920649737182830226970288628085468059938613580348;
      vk[5] = 19705100142818246918004468319393309265228762456859651174188029800643055277572;
      vk[6] = 15446316718391589604783607790809608219791772766867734826001047219086142590;
      vk[7] = 9894589586426091243415515918046305227773039481579517278290468793635349492471;
      vk[8] = 14773513806450151731497353140743856504512155408536295828091098675951888198507;
      vk[9] = 1718366777796593643076952521080859583413745629942258232522586130017276939786;
      vk[10] = 3808533674658468424893349473481053280920375763266367703170284853737275887766;
      vk[11] = 14289346177762507942266456658948394502974415784323312876799700346329839724254;
      vk[12] = 13258405701759746074655969503745009650017529084217271562359896633482446528717;
      vk[13] = 4385455936260908884592987552431870991138520733226896565926921104823460897118;
      return vk;
    } else if (block_size == 64) {
      vk[0] = 4312533557147196237871446689900390221639953121883225380407724199577408444364;
      vk[1] = 13432970972489560595138361120957876611340512178370666483344103769613219452905;
      vk[2] = 12498841423697365587764040782273252231055363131120441880198592675014402901023;
      vk[3] = 62964373500938570687757419934180228145968160628674684060309495064170264976;
      vk[4] = 14914359457537600578323030998805399293388458533357073933297674641870988981011;
      vk[5] = 19648483398341978270191268508902966239141334529048661523613452837346241539020;
      vk[6] = 12458313983808046425243252450027759018610947691050038721888540781412550773776;
      vk[7] = 3846189242196758825260095631992572726357727840244804406109834381975346186838;
      vk[8] = 17961039064296115124971836967503644241656901351872818079814568506228683532747;
      vk[9] = 9474111613434015959198714408040052234872150557928110884890127380105338862806;
      vk[10] = 899339449939316184372494976089470485987532372719094249410148007136875775794;
      vk[11] = 5797649180549724298386106726723581200708749083898834489040518731586903191865;
      vk[12] = 18377500720119101927127612766471089110085475749727897624669621614680206296619;
      vk[13] = 4985914649694646067379859109408480615199392665625192504767034256803934265856;
      return vk;
    } else {
      revert("u");
    }
  }

  function ic(uint16 block_size) internal pure returns (uint256[] memory gammaABC) {
    if (block_size == 8) {
      gammaABC = new uint256[](4);
      gammaABC[0] = 20602652870063323025965832364370898019059891932030924803664987880476572440005;
      gammaABC[1] = 20027892494567071798173978760315782713941578972636609561216506792319465433509;
      gammaABC[2] = 7938788776061719709321259162581577569859197756933777200588365944473876568120;
      gammaABC[3] = 21488709121879614113305434669386735415144470770287952288479787033755856462355;
      return gammaABC;
    } else if (block_size == 16) {
      gammaABC = new uint256[](4);
      gammaABC[0] = 363182234189093982311615669356625708332015498660667720018267286809976923565;
      gammaABC[1] = 4991654421131113831702427285695154459138071502247697000322686338564865457373;
      gammaABC[2] = 7587586722034981598516932231496106685067423550137394390674186069448728113395;
      gammaABC[3] = 5386870583792390365021694312680870676556736822231278453859018022085414146041;
      return gammaABC;
    } else if (block_size == 32) {
      gammaABC = new uint256[](4);
      gammaABC[0] = 17015742272837080966833074687336141628589332695022996269261278861576133601345;
      gammaABC[1] = 19136367422659109595864176335542171283178796045460521250173452155807784866077;
      gammaABC[2] = 10212389889068104346153339313581623545564146182148673279513560292681812810661;
      gammaABC[3] = 20591025089716870288233270372906762935557684585678037867657877704736091929954;
      return gammaABC;
    } else if (block_size == 64) {
      gammaABC = new uint256[](4);
      gammaABC[0] = 1373467101716223128581307488134254490219686115488886568422683862741849998129;
      gammaABC[1] = 7450253559067393527361676304125919850689795197889784339174215861457015108819;
      gammaABC[2] = 17492337278128588333256058177268491841977991674043399996438000715806690422778;
      gammaABC[3] = 9126145799406825925656354149681975813616203378847956533769272054960332621591;
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
