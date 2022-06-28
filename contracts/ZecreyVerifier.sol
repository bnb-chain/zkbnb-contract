// SPDX-License-Identifier: AML

pragma solidity ^0.7.6;

contract ZecreyVerifier {

    function initialize(bytes calldata) external {}

    /// @notice Verifier contract upgrade. Can be external because Proxy contract intercepts illegal calls of this function.
    /// @param upgradeParameters Encoded representation of upgrade parameters
    function upgrade(bytes calldata upgradeParameters) external {}

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
        uint256 num_proofs
    ) internal view returns (
        uint256[] memory proofsAandC,
        uint256[] memory inputAccumulators
    ) {
        uint256 q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        uint256 numPublicInputs = proof_inputs.length / num_proofs;
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
    }

    function prepareBatches(
        uint256[14] memory in_vk,
        uint256[] memory vk_gammaABC,
        uint256[] memory inputAccumulators
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

    function verifyingKey() internal pure returns (uint256[14] memory vk){
        vk[0] = 16906678865498788975769129778395531886156676581174764291157224616278114688848;
        vk[1] = 21340137950997472453871940705726583164222478860763854613467903445866223928062;
        vk[2] = 19956708268574110479607138319374796526106277416447195434822364697132429042412;
        vk[3] = 4997227314214376151929831529000863881003941917115293138807466570950586500752;
        vk[4] = 3105971333452681997378281580401329886256953695643092334604289164033976801327;
        vk[5] = 1576309040194577980375535619654263736269277330216937185532297102501946770327;
        vk[6] = 13872911472560975785313112510148862913866583154178048595482547275449608455230;
        vk[7] = 18928551669766884030318404428440656749535575896920985279192041858450147352837;
        vk[8] = 8127786563793361672237980056810088287201217132651218543130033056649988120443;
        vk[9] = 21061948453159534271515279508504854174715370140069356569693510445226143595184;
        vk[10] = 15715239155945233249610372639559586479168011685975086096495142336382124067910;
        vk[11] = 11360476277806207613482508206808228252023049879678034767819735101079007015767;
        vk[12] = 10376549801515938101724890204804005626891912785268513185450536259571185179051;
        vk[13] = 9065534543831664132519538830903107974890522707630829700588818030271501262929;
        return vk;
    }

    function ic() internal pure returns (uint256[] memory gammaABC){
        gammaABC = new uint256[](8);
        gammaABC[0] = 19503678065476338838601734622707360634312972361956909525732049521323153975659;
        gammaABC[1] = 10512766966812416760987189534889814556951631390781384625514954218218997977986;
        gammaABC[2] = 13153903797974102144209666426762500932880481794932129691618149189956020356573;
        gammaABC[3] = 13148191161406666388383555455035551092821023683109257626149983160728956297103;
        gammaABC[4] = 15994207688199179366441251259268508761317551976552478425232550330598162767071;
        gammaABC[5] = 18996653745651466619845501195056012769238395782751129196058487149958554165485;
        gammaABC[6] = 14511174036289232440708508731788938917335327225549326823595461362350218231507;
        gammaABC[7] = 118779694356457739720150795769709125845094788145166805857637896784920241304;
        return gammaABC;
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
        uint256 num_proofs
    )
    public
    view
    returns (bool success)
    {
        if (num_proofs == 1) {
            return verifyProof(in_proof, proof_inputs);
        }
        uint256[14] memory in_vk = verifyingKey();
        uint256[] memory vk_gammaABC = ic();
        require(in_proof.length == 8 * num_proofs, "Invalid proofs length for a batch");
        require(proof_inputs.length % num_proofs == 0, "Invalid inputs length for a batch");
        require(((vk_gammaABC.length / 2) - 1) == proof_inputs.length / num_proofs, "Mismatching number of inputs for verifying key");

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

    function verifyProof(
        uint256[] memory in_proof,
        uint256[] memory proof_inputs)
    public
    view
    returns (bool)
    {
        uint256[14] memory in_vk = verifyingKey();
        uint256[] memory vk_gammaABC = ic();
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

        uint256 q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        // Performs a sum of gammaABC[0] + sum[ gammaABC[i+1]^proof_inputs[i] ]
        for (uint i = 0; i < proof_inputs.length; i++) {
            // require(proof_inputs[i] < q, "INVALID_INPUT");
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

        uint[24] memory input = [
        // (proof.A, proof.B)
        in_proof[0], in_proof[1], // proof.A   (G1)
        in_proof[2], in_proof[3], in_proof[4], in_proof[5], // proof.B   (G2)

        // (-vk.alpha, vk.beta)
        in_vk[0], NegateY(in_vk[1]), // -vk.alpha (G1)
        in_vk[2], in_vk[3], in_vk[4], in_vk[5], // vk.beta   (G2)

        // (-vk_x, vk.gamma)
        add_input[0], NegateY(add_input[1]), // -vk_x     (G1)
        in_vk[6], in_vk[7], in_vk[8], in_vk[9], // vk.gamma  (G2)

        // (-proof.C, vk.delta)
        in_proof[6], NegateY(in_proof[7]), // -proof.C  (G1)
        in_vk[10], in_vk[11], in_vk[12], in_vk[13]          // vk.delta  (G2)
        ];

        uint[1] memory out;
        assembly {
            success := staticcall(sub(gas(), 2000), 8, input, 768, out, 0x20)
        }
        require(success);
        return out[0] == 1;
    }

}