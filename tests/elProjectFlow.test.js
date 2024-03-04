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
    let notRegisteredBen;
    let ven1;
    let notApprovedVen;
    let eyeTokenContract;
    let referredTokenContract;
    let elProjectContract;
    let rahatDonorContract;
    let rahatClaimContract;
    let forwarderContract;
    let address0 = '0x0000000000000000000000000000000000000000';

    before(async function (){
         const [addr1, addr2,addr3,addr4, addr5, addr6] = await ethers.getSigners();
         deployer = addr1;
         ben1 = addr2;
         ben2 = addr3;
         ven1 = addr4;
         notRegisteredBen = addr5;
         notApprovedVen = addr6;
    });

    describe('Deployment', function(){
        it('Should deploy all required contracts', async function(){
            rahatDonorContract = await ethers.deployContract('RahatDonor', [deployer.address]);
            rahatClaimContract = await ethers.deployContract('RahatClaim');
            forwarderContract = await ethers.deployContract("ERC2771Forwarder",["Rumsan Forwarder"]);
            eyeTokenContract = await ethers.deployContract('RahatToken', [await forwarderContract.getAddress(),'EyeToken', 'EYE',await rahatDonorContract.getAddress(),1]);
            referredTokenContract = await ethers.deployContract('RahatToken', [await forwarderContract.getAddress(),'ReferredToken', 'REF', await rahatDonorContract.getAddress(), 1]);
            elProjectContract = await ethers.deployContract('ELProject', ["ELProject",await eyeTokenContract.getAddress(), await referredTokenContract.getAddress(), await rahatClaimContract.getAddress(), deployer.address,await forwarderContract.getAddress(),1]);
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
            const request = await getMetaTxRequest(ven1,forwarderContract,eyeTokenContract, 'approve',[await elProjectContract.getAddress(),3]);
            const tx = await forwarderContract.execute(request);
            await tx.wait();
            await elProjectContract.redeemTokenByVendor(await eyeTokenContract.getAddress(),1,ven1.address);
            const projectBalanceAfter = await eyeTokenContract.balanceOf(await elProjectContract.getAddress());

        })

        // Case for revert
        it("Should revert if non-admin calls only Admin Functions", async function(){
            await expect(
                rahatDonorContract.connect(ben1)['mintTokenAndApprove(address,address,uint256,string)'](await eyeTokenContract.getAddress(),await elProjectContract.getAddress(),1000,"free voucher for eye and glasses")
              ).to.be.revertedWith('Only owner can execute this transaction');

            await expect(elProjectContract.connect(ben1).addBeneficiary(ben1.address)).to.be.revertedWith('not an admin');

            await expect(elProjectContract.connect(ben1).updateVendor(ben1.address, true)).to.be.revertedWith('not an admin')

            await expect(elProjectContract.connect(ben1).assignClaims(ben1.address)).to.be.revertedWith('not an admin')

        })

        // Revert case for Add Referred Beneficiaries
        it("Should revert if beneficiary being referred is not registered", async function(){
            await expect(
                elProjectContract.addReferredBeneficiaries(
                    ben1.address,
                    notRegisteredBen.address,
                    ven1.address
                )
            ).to.be.revertedWith('referrer ben not registered');
        });
        
        it("Should revert if referring vendor is not approved", async function(){
            await expect(
                elProjectContract.connect(notApprovedVen).addReferredBeneficiaries(
                    ben2.address, 
                    ben1.address, 
                    notApprovedVen.address 
                )
            ).to.be.revertedWith('vendor not approved');
        });
        
        it("Should revert if referral limit is reached for referring beneficiary", async function(){
            elProjectContract.connect(ven1).addReferredBeneficiaries(
                ben2.address,
                ben1.address,
                ven1.address
            )
            await expect(
                elProjectContract.connect(ven1).addReferredBeneficiaries(
                    ben2.address,
                    ben1.address,
                    ven1.address
                )
            ).to.be.revertedWith('referral:limit hit');
        });
        
        // Revert case for Removed Referred Beneficiaries
        it("Should revert if beneficiary being removed is not a referred beneficiary", async function(){
            await expect(
                elProjectContract.removeReferredBeneficiaries(
                    notRegisteredBen.address
                )
            ).to.be.revertedWith('referrer ben not registered');
        });

        // Revert case of Assign Referred Claims
        it("Should revert if claimer is not referred", async function(){
            await expect(
                elProjectContract.connect(ven1).assignRefereedClaims(
                    ben1.address,
                    await referredTokenContract.getAddress()
                )
            ).to.be.revertedWith('claimer not referred');
        });
        
        // Revert case for reverted claims
        it("Should revert if token is not assigned to the claimer", async function(){
            await expect(
                elProjectContract.revertedClaims(
                    notRegisteredBen.address
                )
            ).to.be.revertedWith('Token not assigned');
        });

        // Revert case for reverted referred claims
        it("Should revert if referred token is not assigned to the claimer", async function(){
            await expect(
                elProjectContract.revertedRefereedClaims(
                    ben1.address,
                    await referredTokenContract.getAddress()
                )
            ).to.be.revertedWith('Token not assigned');
        });
        
        // Revert case for request token and refereed token from beneficiary
        it("Should revert if eye voucher is not assigned to the beneficiary", async function(){
            await expect(
                elProjectContract.requestTokenFromBeneficiary(
                    notRegisteredBen.address
                )
            ).to.be.revertedWith('eye voucher not assigned');
        });
        
        it("Should revert if eye voucher is not assigned to the beneficiary", async function(){
            await expect(
                elProjectContract.requestReferredTokenFromBeneficiary(
                    notRegisteredBen.address,
                    await referredTokenContract.getAddress()
                )
            ).to.be.revertedWith('referred voucher not assigned');
        });

        // Revert case for Request Token From Beneficiary
        // it("Should revert if OTP server address is invalid", async function(){
        //     await expect(
        //         elProjectContract['requestTokenFromBeneficiary(address,address,address)'](
        //             ben1.address,
        //             await eyeTokenContract.getAddress(),
        //             address0
        //             )
        //     ).to.be.revertedWith('invalid otp-server');

        // });
        
        it("Should revert if voucher is already claimed by the beneficiary", async function(){        
            await expect(
                elProjectContract.requestTokenFromBeneficiary(
                    ben1.address,
                    await eyeTokenContract.getAddress(), 
                    deployer.address
                )
            ).to.be.revertedWith('Voucher already claimed');
        });        

        // Revert case while increasing token budget
        it("Should revert if voucher is already claimed by the beneficiary", async function(){        
            await expect(
                elProjectContract.increaseTokenBudget(
                    1000,
                    await eyeTokenContract.getAddress(),
                )
            ).to.be.revertedWith('Greater than total supply');
        });


        // Revert case for transfer token to claimer
        // it("Should revert if voucher is already claimed by the beneficiary", async function(){
        
        //     await expect(
        //         elProjectContract['_transferTokenToClaimer(address,address,address)'](
        //             await eyeTokenContract.getAddress(),
        //             ben1.address,
        //             ven1
        //             )
        //     ).to.be.revertedWith('voucher already claimed');
        // });


        // Revert case to update OTP server

        it("Should revert if address is address 0", async function(){        
            await expect(
                elProjectContract.updateOtpServer(
                    address0
                )
            ).to.be.revertedWith('invalid address');
        });

        it("Should revert if address is contract address", async function(){        
            await expect(
                elProjectContract.updateOtpServer(
                    await elProjectContract.getAddress()
                )
            ).to.be.revertedWith('cannot be contract address');
        });
        
        it("Should revert if address is current OTP address", async function(){        
            await expect(
                elProjectContract.updateOtpServer(
                  deployer.address
                )
            ).to.be.revertedWith('no change');
        });


        // Revert Case for redeem token by vendor
        it("Should revert if vendor has insufficient balance", async function(){        
            await expect(
                elProjectContract.redeemTokenByVendor(
                  await eyeTokenContract.getAddress(),
                  1000,
                  ven1
                )
            ).to.be.revertedWith('Insufficient balance');
        });
})
})