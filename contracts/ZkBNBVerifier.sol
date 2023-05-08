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
            vk[0] = 750992530462870756986530872666057546155624511584908880608161359228104635762;
            vk[1] = 7320570183142866163274143342894236371735244409404765293175125524891935010016;
            vk[2] = 14627208509715206609094393681651128162268769386805400950999430819069375269205;
            vk[3] = 7535421855064197869052617681063375078705597902426012036745367026892133331698;
            vk[4] = 9050663423986227977381319984674403330566603750627311140227281151508350267844;
            vk[5] = 15680140541147180980167127817123377591995310082804442295816192377359250420501;
            vk[6] = 21571749854405229227755824803644156790650431306084568134333598092562127037205;
            vk[7] = 5816287635788095366378872484182881709569506937998102635892444886136051761614;
            vk[8] = 18261189451262837524522001417800731138959496861796659200666385789505695266974;
            vk[9] = 20514028824120856685990371784335151853302342053569772122661329990774462838380;
            vk[10] = 6358232355453378726850498626879740657271725992244304888042094877111565023971;
            vk[11] = 12587476505965246132661136384089629612056698890134900501531311017615519929066;
            vk[12] = 4365379950083150965948899421294730478855536805057371518698450738786787829246;
            vk[13] = 13809223875155276240703002471269289348795198549103213582737079682732045856393;
            return vk;
        } else if (block_size == 16) {
            vk[0] = 4102979354548319831374941868298494617042211923057499453123272304632473797477;
            vk[1] = 9401738334930099817342907841710337979191968734365636800307763508098937882301;
            vk[2] = 10301006063559622762250928679258380229673233250321190356977089157620623022437;
            vk[3] = 6255387001197717334608034739985049220603570609809103840962885412618072693723;
            vk[4] = 10931314118272715323041342063713092219331374123141352733820980907934481744336;
            vk[5] = 4653336706379572679760907859099372624729870425745053285520530846793603523116;
            vk[6] = 10122274854967864036786447977234270887234289032802149431715133775187185706450;
            vk[7] = 10071241875298747860436213559471722449059419542290641210496167982784606283787;
            vk[8] = 599396933819061866362999089631689943083481185118506234631734238046738175137;
            vk[9] = 15272850823579745195277989118516735230671756595853535387394386734663665546253;
            vk[10] = 1974966145355059893590677912861344341023910591126909133544182470294522563022;
            vk[11] = 3008536739622606342542326711312840596497540464512843912963978264842072653330;
            vk[12] = 17645150150482317969480066772248056649683621470679555249582170276447579366865;
            vk[13] = 1160831252671151798124075797477138644406110473424190295339459923882267741871;
            return vk;
        } else if (block_size == 32) {
            vk[0] = 5514792013313319280144472645252976421203539039897407873690674379615549569379;
            vk[1] = 16912967139430680492096232315663671400619816487927402545528627300158881453569;
            vk[2] = 21091092176518391938632306350732075040063535265060621826179703658830403082346;
            vk[3] = 14725608277649791532707200671799287214536210664487268324801672571458362743579;
            vk[4] = 7429235482797563304015541976292067157656688929547564065423823102322778458988;
            vk[5] = 11528243246337468704078993529415758902149166358410142012910474564612788244992;
            vk[6] = 4084891243602878733611493532468891584334432744034402839734989910210927763727;
            vk[7] = 20307322328576401716871764459791138395338987710747570578090781052287833677225;
            vk[8] = 8916218972925476739045855711258497464247914466238279219625695401571447585632;
            vk[9] = 16744573293068416197657480599258402272660201729558608388514363019964554794129;
            vk[10] = 3665185772711976924013951587488819378944807694948614678781166155742816910037;
            vk[11] = 9144391903063081749014953023495512357418540139191899706856369909940267722649;
            vk[12] = 3603451383456008920897823230844113134176433900037055850710149974533368098127;
            vk[13] = 21169964584532204609773942738360969071580926756831645392759166454203484533996;
            return vk;
        } else if (block_size == 64) {
            vk[0] = 1031568521549970281872904186384351815919958420591712310816453102595693922916;
            vk[1] = 21190865075299284771850971254426651395287319052582474914971658557450536799101;
            vk[2] = 10894820263501146715712309909682747896744600134563344647526479232551275996197;
            vk[3] = 18567496558323996043390187128968290619767324492908159642610337366230427656124;
            vk[4] = 9083997155923985158042740580557807809327003751353671288383593847538054981834;
            vk[5] = 20834353858538405408925210711773289841783319893342032286742051248060691659826;
            vk[6] = 19857238799768218874370772632639536190387364302751610607769611677305319716331;
            vk[7] = 20925084489220150030464715477949079485416851761890233520435264472067367288953;
            vk[8] = 19080498770567910619898471298273618204840667221099508728624359897382318738369;
            vk[9] = 13599290239257454631428106012090958948298619708769874822609743489127413218264;
            vk[10] = 8689942675224641249093681421475142084043193773900813098597393800798877358736;
            vk[11] = 20767347569173882705940954659809599495159743059577530035146051234401109913924;
            vk[12] = 15341005699961299892463304186505287499603375855753243138164580490199873389309;
            vk[13] = 8514371735149265018363272404753046605954600636920693368763492663480915267710;
            return vk;
        } else {
            revert("u");
        }
    }

    function ic(uint16 block_size) internal pure returns (uint256[] memory gammaABC) {
        if (block_size == 8) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 1057653661259977233655545258531862457750867887579966926773420388025830193837;
            gammaABC[1] = 9339621612820482925423161620484684730077656008174105461755335908392107772345;
            gammaABC[2] = 3054480964109586922596235411246331753951207417134111782145821829460579700578;
            gammaABC[3] = 21813842540785924606777829338051054588232619236327997493637495401344889948895;
            return gammaABC;
        } else if (block_size == 16) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 15436210721081824433863887874889430138761069946428953170312291915039685706128;
            gammaABC[1] = 18749171430680914923623017667768121973362065843490592955682300627560788393666;
            gammaABC[2] = 12473664899580164095383655773379563440317883398329531610507114666846698070760;
            gammaABC[3] = 21621898742974523434709630131321123471838727797171848702596450582641099268440;
            return gammaABC;
        } else if (block_size == 32) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 20220432044254940777531033322444878946422972324742275703319574601329289919294;
            gammaABC[1] = 10019036879085376173175508352301908734314755157603333725210641348593257153594;
            gammaABC[2] = 4348548792977124084992287190013801618761989953235569050641303209281528211179;
            gammaABC[3] = 3468038184057775803026123055206774127119082702107987351981481424903791753406;
            return gammaABC;
        } else if (block_size == 64) {
            gammaABC = new uint256[](4);
            gammaABC[0] = 10348660422225890982181101080347800541170701871995231349555139213798415925713;
            gammaABC[1] = 11381748268093978837128484774909130071710241741256579425816584183404977154967;
            gammaABC[2] = 13064962882732891491142986090818019574959504588581105964243540479368306536289;
            gammaABC[3] = 5075524150333691905000703191675839390331707057043143962705327020137699785910;
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
