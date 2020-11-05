const GetKP3RLPs = artifacts.require("GetKeep3rLPTokens");
const TokenHelper = artifacts.require("TokenHelper");
const KeeperToken = artifacts.require("Keep3rV1");
const Keep3rV1Library = artifacts.require("Keep3rV1Library");

const Addrs = require("../constants/constants").Addrs;
module.exports = async function (deployer) {
  // console.log(deployer.getChainId())
  // await deployer.deploy(TokenHelper);
  // await deployer.link(TokenHelper,GetKP3RLPs);
  // await deployer.deploy(GetKP3RLPs,Addrs.UniRouter[1],Addrs.KP3RToken[1]);
  await deployer.deploy(Keep3rV1Library);
  await deployer.link(Keep3rV1Library, KeeperToken);
  await deployer.deploy(KeeperToken);
};
