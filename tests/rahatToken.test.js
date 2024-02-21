const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('RahatToken', function () {
  let deployer;
  let admin;
  let user;
  let rahatTokenContract;
  let forwarderContract;
  let mintAmount;

  before(async function () {
    const [addr1, addr2, addr3] = await ethers.getSigners();
    deployer = addr1;
    admin = addr2;
    user = addr3;
  });

  describe('Deployment', function () {
    it('Should deploy RahatToken contract', async function () {
      forwarderContract = await ethers.deployContract('ERC2771Forwarder', ['Rumsan Forwarder']);
      rahatTokenContract = await ethers.deployContract('RahatToken', [
        await forwarderContract.getAddress(),
        'RahatToken',
        'RAHAT',
        admin.address,
        18,
      ]);

      // Check if the contract is deployed successfully
      expect(await rahatTokenContract.name()).to.equal('RahatToken');
      expect(await rahatTokenContract.symbol()).to.equal('RAHAT');
      expect(await rahatTokenContract.decimals()).to.equal(18);
    });

    it('Should update token description', async function () {
      const newDescription = 'New token description';
      await rahatTokenContract.connect(admin).updateDescription(newDescription);

      // Check if the description is updated successfully
      expect(await rahatTokenContract.description()).to.equal(newDescription);
    });

    it('Should mint tokens to a user', async function () {
      mintAmount = 100;
      await rahatTokenContract.connect(admin).mint(user.address, mintAmount);

      // Check if the user balance is updated
      const userBalance = await rahatTokenContract.balanceOf(user.address);
      expect(userBalance).to.equal(100);
    });

    it('Should burn tokens from a user', async function () {
      const burnAmount = 2;
      await rahatTokenContract.connect(user).approve(admin.address, burnAmount);

      await rahatTokenContract.connect(admin).burnFrom(user.address, burnAmount);

      // Check if the user balance is updated after burning
      const userBalance = await rahatTokenContract.balanceOf(user.address);
      expect(userBalance).to.equal(mintAmount - burnAmount);
    });
  });
});
