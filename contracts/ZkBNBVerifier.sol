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
            vk[0] = 3620522007278934378623402120683355314728863250583703946840216736743754015122;
            vk[1] = 4731882653398197246848691541624298732859372224542277991532088115487868236687;
            vk[2] = 8389588626912591427088693827420549512767701328790905536671150228537555858776;
            vk[3] = 2947987773120179807942062925134773469803522152714955199936715212000493069494;
            vk[4] = 15319254008315113359319226585075336448649716796146574187960665989542881277316;
            vk[5] = 2753518098046981607805649577241904335014313051052923431481295250075412099725;
            vk[6] = 13724331883217089501661832305054106683418912160854104007070775727702091768208;
            vk[7] = 4301339663849175316100442635650520842737013932600256632205891851991639624963;
            vk[8] = 21471715961935523456558574246331052497902438002357833460489685482438979257684;
            vk[9] = 4687085973621125137536423770496292575014697396283212930129065923722430736002;
            vk[10] = 10236944167147620046937396648817616946896435638716669915700704492859329254831;
            vk[11] = 4749906641611822131475236609162402505237315334771455988889849588051544807217;
            vk[12] = 4820744250659667464937283520137081495454047094953243348811533884402817503468;
            vk[13] = 8998323977825911034469827541270783708073192091781854550254874261931622079648;
            return vk;
        } else if (block_size == 16) {
            vk[0] = 18056907689599780256339296416273773400596926625309717890771557537022020359390;
            vk[1] = 19466842504063750777194151156556186190562990071639013635649887482055898169062;
            vk[2] = 21105331615360942861209643393178117459125064505520499314378127329664821530834;
            vk[3] = 16196435651168809505206874856151245033433216714818936801417076021121782883089;
            vk[4] = 8056654333288414846156197492366745598416694797641358408642837916272711508936;
            vk[5] = 21680877490817180485848942768537710219027921530264195368866648748460634664425;
            vk[6] = 12455722561631991701138576283065111298134760729352285060423028960315203538339;
            vk[7] = 10606638878210703118900119123243420725114514393575996842325715644724314592172;
            vk[8] = 21570024737801329572270900978875366344498517359937572792776432358184614457752;
            vk[9] = 6886303087923219016753223616370549163241643283101138243675218439299387859572;
            vk[10] = 18770826734809001343301757148353031435023711324488527685233188658600685553636;
            vk[11] = 18338506684001976933764141900003187106402779372156926276302807058834561261935;
            vk[12] = 16735611410082166015987634069567505007893697235436301208537340735934579691710;
            vk[13] = 6703824285440157722604863853645722816699695899616702843706320206566186768993;
            return vk;
        } else if (block_size == 32) {
            vk[0] = 10111363986085383262506506816347125850633360299136296171457418856852477752321;
            vk[1] = 9526391545099739055672954260026405252548915543385534368242030670649871252807;
            vk[2] = 6030841251482537422953722773822719512964081386703082322278030761508409184161;
            vk[3] = 14844137868520440729902558621369762887777111572972922825247365035819157044130;
            vk[4] = 16575684573303760682571606354428119814455490779069869140840053460662704605882;
            vk[5] = 245455711046517070607812824742935053185463721008933037445433945583427356370;
            vk[6] = 12197473959908514469579230450313845371107794255763294430171589909367452592689;
            vk[7] = 11412933537276588148074910025200348115005907233846011303494208008012454485609;
            vk[8] = 11724106569936055031745071824501259790650437974301618840755589943565999016502;
            vk[9] = 3559078856788869641919239018558898957874536498897766918176343422316600244278;
            vk[10] = 19664228947791613173653159340894059954169946336201900707954484945618050189188;
            vk[11] = 9745801209518478550736708817603718393444145099046502999357304604574014884393;
            vk[12] = 12849763889363198564872488326481464388912093172934770528739965967169431760870;
            vk[13] = 6277347079504342228357295634754745998312916603248921859675597567860036721856;
            return vk;
        } else if (block_size == 64) {
            vk[0] = 4890287435654757233515766441739629712681704132122883314794328277666644864654;
            vk[1] = 2003350962476578000697346794368636746488473723017741559223372475533934367388;
            vk[2] = 416083302864706855966852844173662424109182325209905603633549204243896726974;
            vk[3] = 13819954364932914468691532259059653988620157353721458349550422115821618838602;
            vk[4] = 19380676928636837293469884698272689614579967187253084972943643095000878892234;
            vk[5] = 13065544816020699749843661302913712861434569573988854117918258704520246707135;
            vk[6] = 16744499618434172106067172159165898675635477891785609807368432046102238751552;
            vk[7] = 6310201745175195289068743632314596784376476875443171000115416709170349341831;
            vk[8] = 7297071515160591159388645761699466980444077252413808144127661595157181591887;
            vk[9] = 14027926573180856031468454705393264264533531489541296585806207651595250923087;
            vk[10] = 12591982410948130447659679859310528403328443253989210263470188275877764236251;
            vk[11] = 6795177144207561542463356251186993384289671064841047860516479715112368470133;
            vk[12] = 12194545730278223877097463152413302576465395688916663553203579850886803870610;
            vk[13] = 17103871203842827332858539696176339665085722184974967102461628643921818970804;
            return vk;
        } else {
            revert("u");
        }
    }

    function ic(uint16 block_size) internal pure returns (uint256[] memory gammaABC) {
        if (block_size == 8) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 13454704647618651791513342499364170866359437457720568978372342731364657110169;
            gammaABC[1] = 4148339013417219469871950501093619822740675595440292695877384308698836068834;
            gammaABC[2] = 4515874139148881116253043180976867378715330608502438192481575694601440375274;
            gammaABC[3] = 18800177267353602495846849000546620335163007896956489483763403071345293475056;
            return gammaABC;
        } else if (block_size == 16) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 18518781907747627834360199438446999329546741881355594051542407364943151078048;
            gammaABC[1] = 18500310160111346792104637263413464950918393459100019290684302813964438371048;
            gammaABC[2] = 17761079969029695497580202178215863465549202063459010841801189984805369890338;
            gammaABC[3] = 8321486049444964137491373922045427969660663095132426421904524887073412584542;
            return gammaABC;
        } else if (block_size == 32) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 19272620418807516396242481144872350730249671521259933959625147684075873334878;
            gammaABC[1] = 8372717452707283878799138932351616529854279428155195892399907180936924375451;
            gammaABC[2] = 8317406760252877679829082765134275373814026940468607204259380733460883838174;
            gammaABC[3] = 21269825688987514568259013165891570480701797667753287771055689263759643487305;
            return gammaABC;
        } else if (block_size == 64) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 4896983558602473030254008045595295995829159054449653261134698830734833703403;
            gammaABC[1] = 12436227141668770123959419822667180916477588517994741650465583466515828695290;
            gammaABC[2] = 6019974152922506234778919781443241171411124881917862012837277388747533674742;
            gammaABC[3] = 11460593899391548977923719208554170913271999687986685291637777289934727864920;
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
