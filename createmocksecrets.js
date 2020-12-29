const ethers = require("ethers");
const fs = require("fs");

const wallet = ethers.Wallet.createRandom();
const data = {mnemonic:wallet.mnemonic.phrase,InfuraProjID:"1d1d1d",EtherscanAPIKey:"12313"};
fs.writeFileSync("secrets.json", JSON.stringify(data));