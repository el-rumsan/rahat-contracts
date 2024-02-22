const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('RahatDonor', function () {
  let admin;
  let projectAddress;
  let rahatTokenContract;
  let rahatDonorContract;

  before(async function () {
    const [deployer, addr1, addr2] = await ethers.getSigners();
    admin = deployer;
    projectAddress = addr1;
  });

  describe('Deployment', function () {
    it('Should deploy RahatDonor contract', async function () {
      rahatDonorContract = await ethers.deployContract('RahatDonor', [admin.address]);

      // Check if the contract is deployed successfully
      expect(await rahatDonorContract.owner()).to.equal(admin.address);
    });

    it('Should create and mint tokens', async function () {
      rahatTokenContract = await ethers.deployContract('RahatToken', [
        await rahatDonorContract.address,
        'RahatToken',
        'RAHAT',
        admin.address,
        18,
      ]);

      // Mint tokens to the RahatDonor contract
      await rahatDonorContract.mintToken(rahatTokenContract.address, 100);

      // Check if the tokens are minted successfully
      const tokenBalance = await rahatTokenContract.balanceOf(rahatDonorContract.address);
      expect(tokenBalance).to.equal(100);
    });

    it('Should register a project and mint tokens with approval', async function () {
      // Register a project with the RahatDonor contract
      await rahatDonorContract.registerProject(projectAddress, true);

      // Mint tokens and approve the project
      await rahatDonorContract.mintTokenAndApprove(rahatTokenContract.address, projectAddress, 50);

      // Check if the tokens are minted and approved successfully
      const projectTokenBalance = await rahatTokenContract.balanceOf(projectAddress);
      expect(projectTokenBalance).to.equal(50);

      const allowance = await rahatTokenContract.allowance(
        rahatDonorContract.address,
        projectAddress
      );
      expect(allowance).to.equal(50);
    });

    it('Should register another project and mint tokens with description', async function () {
      const newProjectAddress = await ethers.Wallet.createRandom().address;

      // Register another project with the RahatDonor contract
      await rahatDonorContract.registerProject(newProjectAddress, true);

      // Mint tokens with description
      await rahatDonorContract.mintTokenAndApprove(
        rahatTokenContract.address,
        newProjectAddress,
        30,
        'Minting tokens for a new project'
      );

      // Check if the tokens are minted with description successfully
      const newProjectTokenBalance = await rahatTokenContract.balanceOf(newProjectAddress);
      expect(newProjectTokenBalance).to.equal(30);
    });

    it('Should add an owner to the token', async function () {
      const newOwnerAddress = await ethers.Wallet.createRandom().address;

      // Add an owner to the token
      await rahatDonorContract.addTokenOwner(rahatTokenContract.address, newOwnerAddress);

      // Check if the owner is added successfully
      const isOwner = await rahatTokenContract.isOwner(newOwnerAddress);
      expect(isOwner).to.equal(true);
    });
  });
});
