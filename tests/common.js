const ethers = require('ethers');

// Function to generate random Ethereum addresses
function generateRandomEthAddress() {
    const wallet = ethers.Wallet.createRandom();
    return wallet.address;
};

function getRandomEthAddress(length) {
    return Array.from({ length }, () => generateRandomEthAddress())
}

function getRandomDonorData(tokenAddress, projectAddress, mintAmount, description) {
    return [
        [tokenAddress, projectAddress, mintAmount, `${description} - 1`, 10, 'USD'],
        [tokenAddress, projectAddress, mintAmount, `${description} - 2`, 10, 'USD'],
        [tokenAddress, projectAddress, mintAmount, `${description} - 3`, 10, 'USD'],
        [tokenAddress, projectAddress, mintAmount, `${description} - 4`, 10, 'USD'],
        [tokenAddress, projectAddress, mintAmount, `${description} - 5`, 10, 'USD'],
    ]
}

module.exports = {getRandomEthAddress, getRandomDonorData};