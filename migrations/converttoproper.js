var Web3 = require("web3");

const Addrs = require("../constants/constants").Addrs;

function main() {
  let properpairs = [];
  Addrs.InitialOraclePairs[1].forEach((element) => {
    properpairs.push(Web3.utils.toChecksumAddress(element));
    console.log(properpairs);
  });
}
main();
