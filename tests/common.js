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
        [tokenAddress, projectAddress, mintAmount, `${description} - 1`],
        [tokenAddress, projectAddress, mintAmount, `${description} - 2`],
        [tokenAddress, projectAddress, mintAmount, `${description} - 3`],
        [tokenAddress, projectAddress, mintAmount, `${description} - 4`],
        [tokenAddress, projectAddress, mintAmount, `${description} - 5`],
    ]
}

module.exports = {getRandomEthAddress, getRandomDonorData};