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
        } else if (block_size == 16) {
            vk[0] = 16799637992313201479680683808014359869232627979359279719992356774775416911897;
            vk[1] = 7873676516286456129720582229619842458237321216666836211962395559229578085724;
            vk[2] = 11542847374081480653345128447488742165493763303359576457343853373346903347636;
            vk[3] = 10313098392793675526199163989790600247622260466533459947469339205059096140881;
            vk[4] = 3425483379527027742840751252184457857785018005825909743856983457107263783756;
            vk[5] = 4577009575555955768096913289008439478280748148444248151354281046482496826148;
            vk[6] = 2153079664895361098201333427754359805793621508658676699618452991031233637537;
            vk[7] = 4013981858192870529353479531337655245610592959650627893661620307382785423978;
            vk[8] = 9761535887513695837530234252097332398109504581489169414524365516691571597545;
            vk[9] = 20418362557538368754087500925852737373356876238651280009596433197028677291885;
            vk[10] = 16080835309167011066256910874450674461227938184134367546727171185650681910453;
            vk[11] = 504480303789650197872938398201280719701700980264990630561111718429930984054;
            vk[12] = 20162984291623576615468719278333685486150941048054156148051346132576212743056;
            vk[13] = 1625451787975810679362609410993987668680694799081784286192456916889427566439;
            return vk;
        } else if (block_size == 32) {
            vk[0] = 6557856980761824751568529358556390459381251053095340041614934762171413941957;
            vk[1] = 2617291848402560535604470907815881645210311034692667818359220237020850180941;
            vk[2] = 8863821287614941389308731599816002453965289543623130924222698974037378568324;
            vk[3] = 5848135435684021276900256116702083831156237928339759696818594608600793098062;
            vk[4] = 9518322572017077727932587999309953361887300272203182614559794169389139823112;
            vk[5] = 4863645621998972547665609465715330401633658638065484608758524767367724907625;
            vk[6] = 14460117352394857492702363470644568045680865503412180856206259455468424007829;
            vk[7] = 9048943866822486419823549437785413630414805173306524928348610249400440372543;
            vk[8] = 20725110130879500430191614796069404635029536231300155518833776012831756403623;
            vk[9] = 17092715879979209302176137487209660752002580036460671849294899026997526923889;
            vk[10] = 3787662473509065746075784795667727705780015551364139057318591667449106006666;
            vk[11] = 21850569755941202999756927951286945562201933655575750490218289102594129828337;
            vk[12] = 16396714759141439344029354868579854340798237191596558732190022084539547456769;
            vk[13] = 3777801699513753130924396036173241211841042594719657024376743619435640465464;
            return vk;
        } else if (block_size == 64) {
            vk[0] = 15147756467873267846626056581713138036328217274977419554396714233791057277698;
            vk[1] = 14241559895041574369939260395306266851131675426097525516461977125022046428823;
            vk[2] = 10344186395951730135716823531011003496375574987056964533217525934042549550247;
            vk[3] = 10628215985857470866250169713673523216107004405643947054413340504963286212104;
            vk[4] = 14234356937108376719145592486057962066892127787789183890630030294328500232909;
            vk[5] = 10657453310502446450629173461261499684028486436400573975380327827587475845385;
            vk[6] = 19521451242208462091345393410665510393545377848264120630394312239066209777573;
            vk[7] = 366529092351131402502751943157991340795976743440400204467008188055734353833;
            vk[8] = 4541359815718694829211904303917326638386070868733509863862349277507180569472;
            vk[9] = 13581008537630376218039433941855168878923933623515284947541718736055607014879;
            vk[10] = 18661633395008617439325090522094553460591142747248240329619044606452276146342;
            vk[11] = 5236535814890237457314835414539582945067609238541244788380212408705527600307;
            vk[12] = 9428884331835826975352420558357661744926511596890198947063667546475687318635;
            vk[13] = 570015624372808991228984491313268840262368811933602233428964393809178415508;
            return vk;
        } else {
            revert("u");
        }
    }

    function ic(uint16 block_size) internal pure returns (uint256[] memory gammaABC) {
        if (block_size == 8) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 14649434776748726606114824897549043725345223405947397984566216138147924313946;
            gammaABC[1] = 15694799062460067161648900813794732494784648227126097736137536777281811878724;
            gammaABC[2] = 19562290364503525143391379247361981963058811504784444565069628412576734898396;
            gammaABC[3] = 10486766752947749952521960315870987175617388599899416827646878013322810980893;
            return gammaABC;
        } else if (block_size == 16) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 10912369988793900172585098548071225496715547684471087813444835824166491496844;
            gammaABC[1] = 8857949996655048151282357057740861749142939226620214434275472105450204731545;
            gammaABC[2] = 18165284296665408355507419677857100759744899116313493763971609889700709621216;
            gammaABC[3] = 13937643157346952613070487746878066610474191140785267378084176029539160312333;
            return gammaABC;
        } else if (block_size == 32) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 153912626987321855767357847396289790461492399325965797728923292251208925810;
            gammaABC[1] = 3418987721923109560095877508366438748882878888727653979556968699889540772849;
            gammaABC[2] = 11406563362639420686025992815770512335563102074800231888061606696173737270438;
            gammaABC[3] = 3051637075688792723720474503308800274169848199639315324238437061777462508922;
            return gammaABC;
        } else if (block_size == 64) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 1739087544562561735886023860683618675027889075086612579132586991653627578344;
            gammaABC[1] = 11370748552449619249547961755326974931503760732297199102641437725046129674663;
            gammaABC[2] = 5615838066036133550506150020447419612152531759352975386400659590583566608720;
            gammaABC[3] = 10536489166124117808784351197256296176816240211229836816347667545237313654940;
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
