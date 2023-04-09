// SPDX-License-Identifier: AML
pragma solidity ^0.7.6;

contract ZkBNBVerifier {

    function initialize(bytes calldata) external {}

    /// @notice Verifier contract upgrade. Can be external because Proxy contract intercepts illegal calls of this function.
    /// @param upgradeParameters Encoded representation of upgrade parameters
    function upgrade(bytes calldata upgradeParameters) external {}

    function calcHash(bytes memory message) internal pure returns (uint256) {
        bytes32 pseudoRandomBytes = sha256(message);
        uint256 q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        uint256 pseudoRandom = addmod(uint256(pseudoRandomBytes), 0, q);
        return pseudoRandom;
    }

    function ScalarField()
    public pure returns (uint256)
    {
        return 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    }

    function NegateY(uint256 Y)
    internal pure returns (uint256)
    {
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        return q - (Y % q);
    }

    function accumulate(
        uint256[] memory in_proof,
        uint256[] memory proof_inputs, // public inputs, length is num_inputs * num_proofs
        uint256[] memory commitments,
        uint256 num_proofs
    ) internal view returns (
        uint256[] memory proofsAandC,
        uint256[] memory inputAccumulators,
        uint256[] memory proofCommitmentKx,
        uint256[] memory proofCommitmentPokKx
    ) {
        uint256 q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        uint256 numPublicInputs = proof_inputs.length / num_proofs;
        for (uint256 proofNumber = 0; proofNumber < num_proofs; proofNumber++) {
            bytes memory commitmentBzs = toBytes(commitments[proofNumber*4], commitments[proofNumber*4+1], proof_inputs[proofNumber*numPublicInputs]);
            proof_inputs[proofNumber*numPublicInputs+numPublicInputs-1] = calcHash(commitmentBzs);
        }
        uint256[] memory entropy = new uint256[](num_proofs);
        inputAccumulators = new uint256[](numPublicInputs + 1);

        for (uint256 proofNumber = 0; proofNumber < num_proofs; proofNumber++) {
            if (proofNumber == 0) {
                entropy[proofNumber] = 1;
            } else {
                // entropy
                entropy[proofNumber] = getProofEntropy(in_proof, proof_inputs, proofNumber);
            }
            require(entropy[proofNumber] != 0, "Entropy should not be zero");
            // here multiplication by 1 is for a sake of clarity only
            inputAccumulators[0] = addmod(inputAccumulators[0], mulmod(1, entropy[proofNumber], q), q);
            for (uint256 i = 0; i < numPublicInputs; i++) {
                // TODO
                // require(proof_inputs[proofNumber * numPublicInputs + i] < q, "INVALID_INPUT");
                // accumulate the exponent with extra entropy mod q
                inputAccumulators[i + 1] = addmod(inputAccumulators[i + 1], mulmod(entropy[proofNumber], proof_inputs[proofNumber * numPublicInputs + i], q), q);
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

        for (uint256 proofNumber = 1; proofNumber < num_proofs; proofNumber++) {
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

        for (uint256 proofNumber = 1; proofNumber < num_proofs; proofNumber++) {
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

        proofCommitmentKx = new uint256[](2);
        add_input[0] = commitments[0];
        add_input[1] = commitments[1];

        for (uint256 proofNumber = 1; proofNumber < num_proofs; proofNumber++) {
            mul_input[0] = commitments[proofNumber * 4];
            mul_input[1] = commitments[proofNumber * 4 + 1];
            mul_input[2] = entropy[proofNumber];
            assembly {
                success := staticcall(sub(gas(), 2000), 7, mul_input, 0x60, add(add_input, 0x40), 0x40)
            }
            require(success, "Failed to call a precompile for G1 multiplication for commitment");

            assembly {
                success := staticcall(sub(gas(), 2000), 6, add_input, 0x80, add_input, 0x40)
            }
            require(success, "Failed to call a precompile for G1 addition for commitment");
        }

        proofCommitmentKx[0] = add_input[0];
        proofCommitmentKx[1] = add_input[1];

        proofCommitmentPokKx = new uint256[](2);
        add_input[0] = commitments[2];
        add_input[1] = commitments[3];

        for (uint256 proofNumber = 1; proofNumber < num_proofs; proofNumber++) {
            mul_input[0] = commitments[proofNumber * 4 + 2];
            mul_input[1] = commitments[proofNumber * 4 + 3];
            mul_input[2] = entropy[proofNumber];
            assembly {
                success := staticcall(sub(gas(), 2000), 7, mul_input, 0x60, add(add_input, 0x40), 0x40)
            }
            require(success, "Failed to call a precompile for G1 multiplication for commitment");

            assembly {
                success := staticcall(sub(gas(), 2000), 6, add_input, 0x80, add_input, 0x40)
            }
            require(success, "Failed to call a precompile for G1 addition for commitment");
        }

        proofCommitmentPokKx[0] = add_input[0];
        proofCommitmentPokKx[1] = add_input[1];
    }

    function prepareBatches(
        uint256[22] memory in_vk,
        uint256[] memory vk_gammaABC,
        uint256[] memory inputAccumulators,
        uint256[] memory proofCommitmentKx
    ) internal view returns (
        uint256[4] memory finalVksAlphaX
    ) {
        // Compute the linear combination vk_x using accumulator
        // First two fields are used as the sum and are initially zero
        uint256[4] memory add_input;
        uint256[3] memory mul_input;
        bool success;

        // Performs a sum(gammaABC[i] * inputAccumulator[i])
        for (uint256 i = 0; i < inputAccumulators.length; i++) {
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

        add_input[2] = proofCommitmentKx[0];
        add_input[3] = proofCommitmentKx[1];

        assembly {
        // ECADD from four elements that are in add_input and output into first two elements of add_input
            success := staticcall(sub(gas(), 2000), 6, add_input, 0x80, add_input, 0x40)
        }
        require(success, "Failed to call a precompile for G1 addition for input accumulator");

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

    function verifyingKey(uint16 block_size) internal pure returns (uint256[22] memory vk) {
        if (block_size == 10) {
            vk[0] = 19845275157305329817270712870519327215928423877226694661654428772600392127152;
            vk[1] = 5922205489357142657390257703736199065513502779240849693441482100386398267819;
            vk[2] = 1645848163885121275220139782053746932358907108335041462279771492889258039331;
            vk[3] = 6655739033283305608289797207305117981238198119342833785876005459365504160204;
            vk[4] = 9276425540726747244089840267709488572797545832022628786459156828316307139110;
            vk[5] = 15003585545947341870333319385358644806988202419252599345781997183717698525242;
            vk[6] = 13247951322102494626900509434764500167395205191629382888796428668361334021498;
            vk[7] = 4026958170738042276473170623611565136963263409240730945263149557395114552702;
            vk[8] = 6512429680125388706271036610609682545361127101289075027835543443745930617012;
            vk[9] = 5674757341978077172259191117474559762537064248795618381253762677618980013599;
            vk[10] = 8684269618223764824471771605556307616072271922372547557364789871752166671729;
            vk[11] = 1469314478632896630621510280152153112645074597070383750000134930577145409276;
            vk[12] = 17901501574817329782989482824606660963215201428244130213207816543773230951501;
            vk[13] = 14748323676376642351570777124193896608562858281323044336913850926188595395642;
            vk[14] = 15441851398081905723229859929074729503086595290721268231181172220162000804071;
            vk[15] = 9760778954455154901431403698364139801760641153935749707489925091887679730056;
            vk[16] = 1461830313526063875130343207402771263144508948525039197015117912274617688425;
            vk[17] = 9187560299696423682366016256662795080820537382916262442152078670009486255909;
            vk[18] = 2011218808780311195760069163620178658189889778386923877620985226990410816748;
            vk[19] = 15435969678631777703822761975116324919528649384580180428913618169166190099310;
            vk[20] = 11389472479695792187508254453204572754657983897689351287753772727653041448230;
            vk[21] = 3693165019018644723941696519775578442333913601280109321750917848156896443485;
            return vk;
        } else if (block_size == 1) {
            vk[0] = 19845275157305329817270712870519327215928423877226694661654428772600392127152;
            vk[1] = 5922205489357142657390257703736199065513502779240849693441482100386398267819;
            vk[2] = 1645848163885121275220139782053746932358907108335041462279771492889258039331;
            vk[3] = 6655739033283305608289797207305117981238198119342833785876005459365504160204;
            vk[4] = 9276425540726747244089840267709488572797545832022628786459156828316307139110;
            vk[5] = 15003585545947341870333319385358644806988202419252599345781997183717698525242;
            vk[6] = 13247951322102494626900509434764500167395205191629382888796428668361334021498;
            vk[7] = 4026958170738042276473170623611565136963263409240730945263149557395114552702;
            vk[8] = 6512429680125388706271036610609682545361127101289075027835543443745930617012;
            vk[9] = 5674757341978077172259191117474559762537064248795618381253762677618980013599;
            vk[10] = 8684269618223764824471771605556307616072271922372547557364789871752166671729;
            vk[11] = 1469314478632896630621510280152153112645074597070383750000134930577145409276;
            vk[12] = 17901501574817329782989482824606660963215201428244130213207816543773230951501;
            vk[13] = 14748323676376642351570777124193896608562858281323044336913850926188595395642;
            vk[14] = 15441851398081905723229859929074729503086595290721268231181172220162000804071;
            vk[15] = 9760778954455154901431403698364139801760641153935749707489925091887679730056;
            vk[16] = 1461830313526063875130343207402771263144508948525039197015117912274617688425;
            vk[17] = 9187560299696423682366016256662795080820537382916262442152078670009486255909;
            vk[18] = 2011218808780311195760069163620178658189889778386923877620985226990410816748;
            vk[19] = 15435969678631777703822761975116324919528649384580180428913618169166190099310;
            vk[20] = 11389472479695792187508254453204572754657983897689351287753772727653041448230;
            vk[21] = 3693165019018644723941696519775578442333913601280109321750917848156896443485;
            return vk;
        } else {
            revert("u");
        }
    }

    function ic(uint16 block_size) internal pure returns (uint256[] memory gammaABC) {
        if (block_size == 10) {
            gammaABC = new uint256[](10);
            gammaABC[0] = 17398737229141406093750087386448053117094619507158245455991836877092665338748; // vk.K[0].X
            gammaABC[1] = 19489598086828763855562128806729640022348544315375116692279680855651638449865; // vk.K[0].Y
            gammaABC[2] = 10800383561645168233196988494743911810136654265054911923198926329341727678658; // vk.K[1].X
            gammaABC[3] = 18227146134060743457767300880246520276274093420861732388050919455812293998989; // vk.K[1].Y
            gammaABC[4] = 10562118524020482130640648524803112772729907046796250048475749309474342289207; // vk.K[2].X
            gammaABC[5] = 15239640106902636009286072350134119643106815792189139927972735538781137403660; // vk.K[2].Y
            gammaABC[6] = 10562118524020482130640648524803112772729907046796250048475749309474342289207; // vk.K[3].X
            gammaABC[7] = 6648602764936639212960333395123155445589495365108683734716302355864088804923; // vk.K[3].Y
            gammaABC[8] = 4645650585440261187262147979163175014259192824703598857921824335155310329869; // vk.K[4].X
            gammaABC[9] = 5062130210350555025357164978656153210678644546058473938933671473560196950206; // vk.K[4].Y
            return gammaABC;
        } else if (block_size == 1) {
            gammaABC = new uint256[](10);
            gammaABC[0] = 17398737229141406093750087386448053117094619507158245455991836877092665338748; // vk.K[0].X
            gammaABC[1] = 19489598086828763855562128806729640022348544315375116692279680855651638449865; // vk.K[0].Y
            gammaABC[2] = 10800383561645168233196988494743911810136654265054911923198926329341727678658; // vk.K[1].X
            gammaABC[3] = 18227146134060743457767300880246520276274093420861732388050919455812293998989; // vk.K[1].Y
            gammaABC[4] = 10562118524020482130640648524803112772729907046796250048475749309474342289207; // vk.K[2].X
            gammaABC[5] = 15239640106902636009286072350134119643106815792189139927972735538781137403660; // vk.K[2].Y
            gammaABC[6] = 10562118524020482130640648524803112772729907046796250048475749309474342289207; // vk.K[3].X
            gammaABC[7] = 6648602764936639212960333395123155445589495365108683734716302355864088804923; // vk.K[3].Y
            gammaABC[8] = 4645650585440261187262147979163175014259192824703598857921824335155310329869; // vk.K[4].X
            gammaABC[9] = 5062130210350555025357164978656153210678644546058473938933671473560196950206; // vk.K[4].Y
            return gammaABC;
        } else {
            revert("u");
        }
    }


    function getProofEntropy(
        uint256[] memory in_proof,
        uint256[] memory proof_inputs,
        uint proofNumber
    )
    internal pure returns (uint256)
    {
        // Truncate the least significant 3 bits from the 256bit entropy so it fits the scalar field
        return uint256(
            keccak256(
                abi.encodePacked(
                    in_proof[proofNumber * 8 + 0], in_proof[proofNumber * 8 + 1], in_proof[proofNumber * 8 + 2], in_proof[proofNumber * 8 + 3],
                    in_proof[proofNumber * 8 + 4], in_proof[proofNumber * 8 + 5], in_proof[proofNumber * 8 + 6], in_proof[proofNumber * 8 + 7],
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
        uint256[] memory commitments, // G1 Points commitment/commitmentPok
        uint256 num_proofs,
        uint16 block_size
    )
    public
    view
    returns (bool success)
    {
        if (num_proofs == 1) {
            return verifyProof(in_proof, proof_inputs, commitments, block_size);
        }
        uint256[22] memory in_vk = verifyingKey(block_size);
        uint256[] memory vk_gammaABC = ic(block_size);
        require(in_proof.length == 8 * num_proofs, "Invalid proofs length for a batch");
        require(proof_inputs.length % num_proofs == 0, "Invalid inputs length for a batch");
        require(((vk_gammaABC.length / 2) - 1) == proof_inputs.length / num_proofs, "Mismatching number of inputs for verifying key");

        // strategy is to accumulate entropy separately for all the "constant" elements
        // (accumulate only for G1, can't in G2) of the pairing equation, as well as input verification key,
        // postpone scalar multiplication as much as possible and check only one equation
        // by using 3+num_proofs pairings only

        uint256[] memory proofsAandC;
        uint256[] memory inputAccumulators;
        uint256[] memory proofCommitmentKx;
        uint256[] memory proofCommitmentPokKx;
        (proofsAandC, inputAccumulators, proofCommitmentKx, proofCommitmentPokKx) = accumulate(in_proof, proof_inputs, commitments, num_proofs);

        uint256[4] memory finalVksAlphaX = prepareBatches(in_vk, vk_gammaABC, inputAccumulators, proofCommitmentKx);

        uint256[] memory inputs = new uint256[](6 * num_proofs + 30);
        // first num_proofs pairings e(ProofA, ProofB)
        for (uint256 proofNumber = 0; proofNumber < num_proofs; proofNumber++) {
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

        // fifth pairing e(proof.commitment, vk.g)
        inputs[num_proofs * 6 + 18] = proofCommitmentKx[0];
        inputs[num_proofs * 6 + 19] = proofCommitmentKx[1];
        inputs[num_proofs * 6 + 20] = in_vk[14];
        inputs[num_proofs * 6 + 21] = in_vk[15];
        inputs[num_proofs * 6 + 22] = in_vk[16];
        inputs[num_proofs * 6 + 23] = in_vk[17];

        // sixth pairing e(proof.commitmentPok, vk.gRootSigmaNeg)
        inputs[num_proofs * 6 + 24] = proofCommitmentPokKx[0];
        inputs[num_proofs * 6 + 25] = proofCommitmentPokKx[1];
        inputs[num_proofs * 6 + 26] = in_vk[18];
        inputs[num_proofs * 6 + 27] = in_vk[19];
        inputs[num_proofs * 6 + 28] = in_vk[20];
        inputs[num_proofs * 6 + 29] = in_vk[21];


        uint256 inputsLength = inputs.length * 32;
        uint[1] memory out;
        require(inputsLength % 192 == 0, "Inputs length should be multiple of 192 bytes");

        // return true;
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(inputs, 0x20), inputsLength, out, 0x20)
        }
        require(success, "Failed to call pairings functions");
        return out[0] == 1;
    }


    function toBytes(uint256 x, uint256 y, uint256 z) public pure returns (bytes memory) {
        bytes memory b = new bytes(96);
        assembly { mstore(add(b, 32), x) }
        assembly { mstore(add(b, 64), y) }
        // depends on how much public inputs are committed
        assembly { mstore(add(b, 96), z) }
        return b;
    }

    function verifyProof(
        uint256[] memory in_proof,
        uint256[] memory proof_inputs,
        uint256[] memory commitments, // G1 Points commitment/commitmentPok
        uint16 block_size)
    public
    view
    returns (bool)
    {
        // cal the proof inputs
        bytes memory commitmentBzs = toBytes(commitments[0], commitments[1], proof_inputs[0]);
        proof_inputs[proof_inputs.length-1] = calcHash(commitmentBzs);

        uint256[22] memory in_vk = verifyingKey(block_size);
        uint256[] memory vk_gammaABC = ic(block_size);
        require(((vk_gammaABC.length / 2) - 1) == proof_inputs.length);
        require(in_proof.length == 8);
        // Compute the linear combination vk_x
        uint256[3] memory mul_input;
        uint256[4] memory add_input;
        bool success;
        uint m = 2;

        // First two fields are used as the sum
        add_input[0] = vk_gammaABC[0];
        add_input[1] = vk_gammaABC[1];

        // Performs a sum of gammaABC[0] + sum[ gammaABC[i+1]^proof_inputs[i] ]
        for (uint i = 0; i < proof_inputs.length; i++) {
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

        add_input[2] = commitments[0];
        add_input[3] = commitments[1];
        assembly {
        // ECADD
            success := staticcall(sub(gas(), 2000), 6, add_input, 0xc0, add_input, 0x60)
        }
        require(success);

        uint[36] memory input = [
         // (proof.A, proof.B)
        in_proof[0], in_proof[1], // proof.A   (G1)
        in_proof[2], in_proof[3], in_proof[4], in_proof[5], // proof.B   (G2)

        // (-proof.C, vk.delta)
        in_proof[6], in_proof[7], // -proof.C  (G1)
        in_vk[10], in_vk[11], in_vk[12], in_vk[13],          // vk.delta  (G2)

        // (-vk.alpha, vk.beta)
        in_vk[0], NegateY(in_vk[1]), // -vk.alpha (G1)
        in_vk[2], in_vk[3], in_vk[4], in_vk[5], // vk.beta   (G2)

        // (-vk_x, vk.gamma)
        add_input[0], NegateY(add_input[1]), // -vk_x     (G1)
        in_vk[6], in_vk[7], in_vk[8], in_vk[9], // vk.gamma  (G2)

        // (proof.commitment, vk.g)
        commitments[0], commitments[1],
        in_vk[14], in_vk[15], in_vk[16], in_vk[17],

        // (proof.commitmentPok, vk.gRootSigmaNeg)
        commitments[2], commitments[3],
        in_vk[18], in_vk[19], in_vk[20], in_vk[21]
        ];

        input[7] = NegateY(input[7]);

        uint[1] memory out;
        assembly {
            success := staticcall(sub(gas(), 2000), 8, input, 1152, out, 0x20)
        }
        require(success);
        return out[0] == 1;
    }
}
