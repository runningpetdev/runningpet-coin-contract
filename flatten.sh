#!/bin/zsh
truffle-flattener contracts/RunningPetCoin.sol > RunningPetCoin.flatten.sol
truffle-flattener contracts/RunningPetCoinMultiSigWallet.sol > RunningPetCoinMultiSigWallet.flatten.sol
