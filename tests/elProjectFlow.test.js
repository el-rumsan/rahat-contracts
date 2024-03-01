const {expect} = require('chai');
const {ethers} = require('hardhat');

const {signMetaTxRequest} = require("../utils/signer")

async function getMetaTxRequest(signer, forwarderContract, storageContract, functionName, params) {
    return signMetaTxRequest(
      signer,
      forwarderContract,
      {
        from: signer.address,
        to: storageContract.target,
        data: storageContract.interface.encodeFunctionData(functionName, params),
      },
    )
  
  }

async function getHash(otp){
    const bytes32 = ethers.toUtf8Bytes(otp);
    const keecakHash = ethers.keccak256(bytes32);
    return keecakHash;
    
}


describe('------ ElProjectFlow Tests ------', function () {
    let deployer
    let ben1;
    let ben2;
    let ven1;
    let eyeTokenContract;
    let referredTokenContract;
    let elProjectContract;
    let rahatDonorContract;
    let rahatClaimContract;
    let forwarderContract;



    before(async function (){
         const [addr1, addr2,addr3,addr4] = await ethers.getSigners();
         deployer = addr1;
         ben1 = addr2;
         ben2 = addr3;
         ven1 = addr4;
    });

    describe('Deployment', function(){
        it('Should deploy all required contracts', async function(){
            rahatDonorContract = await ethers.deployContract('RahatDonor', [deployer.address]);
            rahatClaimContract = await ethers.deployContract('RahatClaim');
            forwarderContract = await ethers.deployContract("ERC2771Forwarder",["Rumsan Forwarder"]);
            eyeTokenContract = await ethers.deployContract('RahatToken', [await forwarderContract.getAddress(),'EyeToken', 'EYE',await rahatDonorContract.getAddress(),1]);
            referredTokenContract = await ethers.deployContract('RahatToken', [await forwarderContract.getAddress(),'ReferredToken', 'REF', await rahatDonorContract.getAddress(), 1]);
            elProjectContract = await ethers.deployContract('ELProject', ["ELProject",await eyeTokenContract.getAddress(), await referredTokenContract.getAddress(), await rahatClaimContract.getAddress(), deployer.address,await forwarderContract.getAddress(),3]);
            await elProjectContract.updateAdmin(await rahatDonorContract.getAddress(),true);
            rahatDonorContract.registerProject(await elProjectContract.getAddress(),true);
           
        })

        it("Should mint the eye and referred tokens", async function(){
            await rahatDonorContract['mintTokenAndApprove(address,address,uint256,string)'](await eyeTokenContract.getAddress(),await elProjectContract.getAddress(),1000,"free voucher for eye and glasses");
            await rahatDonorContract['mintTokenAndApprove(address,address,uint256,string)'](await referredTokenContract.getAddress(),await elProjectContract.getAddress(),3000,"dscount voucher for referred token");
            const eyeTotalSupply = await eyeTokenContract.totalSupply();
            expect(Number(eyeTotalSupply)).to.equal(1000);
            expect(Number(await referredTokenContract.totalSupply())).to.equal(3000);  
        })

        it("Should add beneficiary", async function(){
            await elProjectContract.addBeneficiary(ben1.address);
            expect(await elProjectContract.isBeneficiary(ben1.address)).to.equal(true);
        })

        it("Should update vendor", async function(){
            await elProjectContract.updateVendor(ven1.address,true);
            expect(await elProjectContract.checkVendorStatus(ven1.address)).to.equal(true);
        })

        it("Should assign free voucher claims to the beneficiaries", async function(){
            await elProjectContract.assignClaims(ben1.address);
            expect(Number(await elProjectContract.eyeVoucherAssigned())).to.equal(1);
            expect (await elProjectContract.beneficiaryEyeVoucher(ben1.address)).to.equal(await eyeTokenContract.getAddress());
            expect(await elProjectContract.beneficiaryClaimStatus(ben1.address,await eyeTokenContract.getAddress())).to.equal(false);
        })
        it("Should refer the new beneficiaries", async function(){
            await elProjectContract.addReferredBeneficiaries(ben2.address,ben1.address,ven1.address);
            const referredBeneficiary = await elProjectContract.referredBenficiaries(ben2.address);
            expect(referredBeneficiary[0]).to.equal(ben2.address);
            expect(referredBeneficiary[1]).to.equal(ven1.address);
            expect(referredBeneficiary[2]).to.equal(ben1.address);
            const benList = await elProjectContract.getTotalBeneficiaries();
            expect(Number(benList.enrolledBen)).to.equal(1);
            expect(Number(benList.referredBen)).to.equal(1);
        })
    
        it("Should assign referred voucher claims to the beneficiaries", async function(){
            await elProjectContract.connect(ven1).assignRefereedClaims(ben2.address, await referredTokenContract.getAddress());
            expect(Number(await elProjectContract.referredVoucherAssigned())).to.equal(1);
            expect (await elProjectContract.beneficiaryReferredVoucher(ben2.address)).to.equal(await referredTokenContract.getAddress());
            expect(await elProjectContract.beneficiaryClaimStatus(ben2.address,await referredTokenContract.getAddress())).to.equal(false);
        })

        it("Should create the request for the claim", async function(){
            const tx = await elProjectContract.connect(ven1).requestTokenFromBeneficiary(ben1.address);
            const receipt = await tx.wait();
            const claimId = await receipt.logs[0].topics[1];
            expect(Number(claimId)).to.equal(1);
            expect(await elProjectContract.tokenRequestIds(ven1.address,ben1.address)).to.equal(1);
            const rahatClaim = await rahatClaimContract.claims(1);
            expect(rahatClaim[0]).to.equal(await elProjectContract.getAddress());
            expect(rahatClaim[1]).to.equal(ven1.address);
            expect(rahatClaim[2]).to.equal(ben1.address);
            expect(rahatClaim[4]).to.equal(await eyeTokenContract.getAddress());
        })

        it("Should add the otp for claim", async function(){
            const keecakHash = await getHash("1234");
           const provider = ethers.provider;
            // Get the current block timestamp
            const blockNumber = await provider.getBlockNumber();
            const block = await provider.getBlock(blockNumber);
            const timestamp = block.timestamp;

            await rahatClaimContract.addOtpToClaim(1,keecakHash,timestamp+1000);
            const claim = await rahatClaimContract.claims(1);
            expect(claim[6]).to.equal(keecakHash);
        })

        it("Should process the otp and transfer the claimed token to vendor wallet", async function(){
            const tx = await elProjectContract.connect(ven1).processTokenRequest(ben1.address,"1234");
            const ven1Balance = await eyeTokenContract.balanceOf(ven1.address);
            expect(Number(ven1Balance)).to.equal(1);
            const eyeTokenRedeemed = await elProjectContract.eyeVoucherRedeemedByVendor(ven1.address);
            expect(Number(eyeTokenRedeemed)).to.equal(1);
            // await elProjectContract.approveProject(await eyeTokenContract.getAddress(),1);
        })

        it("Should transfer claimed token from vendor to project contract", async function(){
            const projectBalanceBefore = await eyeTokenContract.balanceOf(await elProjectContract.getAddress());
            const request = await getMetaTxRequest(ven1,forwarderContract,eyeTokenContract, 'approve',[await elProjectContract.getAddress(),1]);
            const tx = await forwarderContract.execute(request);
            await tx.wait();
            await elProjectContract.redeemTokenByVendor(await eyeTokenContract.getAddress(),1,ven1.address);
            const projectBalanceAfter = await eyeTokenContract.balanceOf(await elProjectContract.getAddress());

        })


})
})