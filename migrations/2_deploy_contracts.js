var RunningPetCoin = artifacts.require("./contracts/RunningPetCoin.sol");
var RunningPetCoinMultiSigWallet = artifacts.require("./contracts/RunningPetCoinMultiSigWallet.sol");
var RunningPetCoinMultiSigWalletWithMint = artifacts.require("./contracts/RunningPetCoinMultiSigWalletWithMint.sol");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(RunningPetCoin, 'RunningPet', 'RunningPetCoin', accounts[0], accounts[1], accounts[2]).then( () => {
    console.log(`RunningPetCoin deployed: address = ${RunningPetCoin.address}`);

    deployer.
      deploy(RunningPetCoinMultiSigWallet, [accounts[0], accounts[1], accounts[2]], 2, RunningPetCoin.address,
          "vault multisig wallet");

      deployer.
      deploy(RunningPetCoinMultiSigWalletWithMint, [accounts[0], accounts[1], accounts[2]], 2, RunningPetCoin.address,
          "vault multisig wallet with mint");

  });
};
