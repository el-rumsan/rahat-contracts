const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('RahatTreasury', function () {
  let deployer;
  let rahatTreasuryContract;

  before(async function () {
    [deployer] = await ethers.getSigners();
  });

  beforeEach(async function () {
    rahatTreasuryContract = await ethers.deployContract('RahatTreasury')
  });

  it('Should create treasury', async function () {
    const year = '2024';
    const budget = ethers.parseEther('1000');
    const country = 'ExampleCountry';

    await expect(
      rahatTreasuryContract.createTreasury(year, budget, country)
    )
    .to.emit(rahatTreasuryContract, 'TreasuryCreated')
    .withArgs(year, budget, country);

    const treasury = await rahatTreasuryContract.treasury(1);
    expect(treasury.year).to.equal(year);
    expect(treasury.budget).to.equal(budget);
    expect(treasury.country).to.equal(country);
  });

  it('Should increase budget', async function () {
    const year = '2024';
    const budget = ethers.parseEther('1000');
    const country = 'ExampleCountry';

    await rahatTreasuryContract.createTreasury(year, budget, country);

    const increaseAmount = ethers.parseEther('500');

    await expect(
      rahatTreasuryContract.increaseBudget(1, increaseAmount)
    )
    .to.emit(rahatTreasuryContract, 'BudgetIncreased')
    .withArgs(1, increaseAmount);

    const treasury = await rahatTreasuryContract.treasury(1);
    expect(treasury.budget).to.equal(budget + increaseAmount);
  });

  it('Should redeem token', async function () {
    const year = '2024';
    const budget = ethers.parseEther('1000');
    const country = 'ExampleCountry';

    await rahatTreasuryContract.createTreasury(year, budget, country);

    const redeemAmount = ethers.parseEther('200');

    await expect(
      rahatTreasuryContract.redeemToken(1, redeemAmount)
    )
    .to.emit(rahatTreasuryContract, 'BudgetRedeemed')
    .withArgs(1, redeemAmount);

    const treasury = await rahatTreasuryContract.treasury(1);

    expect(treasury.budget).to.equal(budget - redeemAmount);
  });
});
