const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('RahatDonor', function () {
  let deployer;
  let admin;
  let user;
  let rahatDonorContract;
  let rahatTokenContract;
  let elProjectContract;

  before(async function () {
    const [deployerAddr, adminAddr, userAddr, projectAdr] = await ethers.getSigners();
    deployer = deployerAddr;
    admin = adminAddr;
    user = userAddr;
    project = projectAdr;
  });

  describe('Deployment', function () {
    it('Should deploy RahatDonor contract', async function () {
      rahatDonorContract = await ethers.deployContract('RahatDonor', [admin.address]);

      // Check if the contract is deployed successfully
      //   expect(await rahatDonorContract.owner()).to.equal(admin.address);
    });

    it('Should deploy RahatToken contract', async function () {
      const forwarderContract = await ethers.deployContract('ERC2771Forwarder', [
        'Rumsan Forwarder',
      ]);
      rahatTokenContract = await ethers.deployContract('RahatToken', [
        await forwarderContract.getAddress(),
        'RahatToken',
        'RAHAT',
        await rahatDonorContract.getAddress(),
        18,
      ]);

      // Check if the RahatToken contract is deployed successfully
      expect(await rahatTokenContract.name()).to.equal('RahatToken');
      expect(await rahatTokenContract.symbol()).to.equal('RAHAT');
      expect(await rahatTokenContract.decimals()).to.equal(18);
    });

    it('Should deploy all required contracts', async function () {
      let rahatClaimContract = await ethers.deployContract('RahatClaim');
      let forwarderContract = await ethers.deployContract('ERC2771Forwarder', ['Rumsan Forwarder']);
      let eyeTokenContract = await ethers.deployContract('RahatToken', [
        await forwarderContract.getAddress(),
        'EyeToken',
        'EYE',
        await rahatDonorContract.getAddress(),
        1,
      ]);
      elProjectContract = await ethers.deployContract('ELProject', [
        'ELProject',
        await eyeTokenContract.getAddress(),
        await rahatTokenContract.getAddress(),
        await rahatClaimContract.getAddress(),
        deployer.address,
        await forwarderContract.getAddress(),
      ]);
      await elProjectContract.updateAdmin(await rahatDonorContract.getAddress(), true);
    });
  });

  describe('Token Minting and Approval', function () {
    it('Should mint tokens and approve project', async function () {
      const mintAmount = 100;
      await rahatDonorContract
        .connect(admin)
        .registerProject(await elProjectContract.getAddress(), true);

      // Mint tokens and approve project
      await rahatDonorContract
        .connect(admin)
        .mintTokenAndApprove(
          await rahatTokenContract.getAddress(),
          await elProjectContract.getAddress(),
          mintAmount
        );

      // Check if the project balance is updated
      //   const projectBalance = await rahatTokenContract.balanceOf(user.address);
      //   expect(projectBalance).to.equal(mintAmount);
    });
  });
});
