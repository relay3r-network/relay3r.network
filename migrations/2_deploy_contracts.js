var Web3 = require("web3");

//Keeoer core contracts
const Keep3rV1Helper = artifacts.require("Keep3rV1Helper");
const Relay3rV1 = artifacts.require("Relay3rV1");
// const Keep3rV1Library = artifacts.require("Keep3rV1Library");
const Keep3rV1JobRegistry = artifacts.require("Keep3rV1JobRegistry");
const Governance = artifacts.require("Governance")
//Jobs
const UnitradeRelay3r = artifacts.require("UnitradeRelay3r");
const YearnV1EarnKeep3r = artifacts.require("YearnV1EarnKeep3r");
const SushiswapV2Keep3r = artifacts.require("SushiswapV2Keep3r");
const UniswapV2SlidingOracle = artifacts.require("UniswapV2SlidingOracle");

//LP contracts
const GetKP3RLPs = artifacts.require("GetKeep3rLPTokens");
const TokenHelper = artifacts.require("TokenHelper");
const Addrs = require("../constants/constants").Addrs;
const InitialDeploy = false;
module.exports = async function (deployer) {
  // console.log(deployer.getChainId())
  const keeperTokenD = await Relay3rV1.at(Addrs.RL3RToken[1]);

  if (InitialDeploy) {
    //Deploy token with library
    // await deployer.deploy(Keep3rV1Library);
    // await deployer.link(Keep3rV1Library, KeeperToken);
    // await deployer.deploy(KeeperToken);
    const InitiaLSupply = Web3.utils.toWei("200000", "ether");
    //Mint initial supply
    await keeperTokenD.mint(InitiaLSupply); //10000 RL3R

    //Deploy helper
    await deployer.deploy(Keep3rV1Helper);
    const keeperHelperD = await Keep3rV1Helper.deployed();
    console.log(`KEEPER HELPER IS ${keeperHelperD.address}`);
    await keeperHelperD.setToken(Addrs.RL3RToken[1]);
    //Set helper on keeper token
    await keeperTokenD.setKeep3rHelper(keeperHelperD.address);

    //Deploy YearnV1EarnKeep3r
    await deployer.deploy(YearnV1EarnKeep3r, Addrs.RL3RToken[1]);
    const YearnV1EarnKeep3rJob = await YearnV1EarnKeep3r.deployed();
    //Add to jobs on keeper token
    await keeperTokenD.addJob(YearnV1EarnKeep3rJob.address);

    //Deploy SushiswapV2Keep3r
    await deployer.deploy(SushiswapV2Keep3r, Addrs.RL3RToken[1]);
    const SushiswapV2Keep3rJob = await SushiswapV2Keep3r.deployed();
    //Add to jobs on keeper token
    await keeperTokenD.addJob(SushiswapV2Keep3rJob.address);

    //Deploy UniswapV2SlidingOracle
    await deployer.deploy(UniswapV2SlidingOracle, Addrs.RL3RToken[1]);
    const UniswapV2SlidingOracleJob = await UniswapV2SlidingOracle.deployed();
    //Add to jobs on keeper token
    await keeperTokenD.addJob(UniswapV2SlidingOracleJob.address);

    //Deploy UnitradeJob
    await deployer.deploy(UnitradeRelay3r, Addrs.RL3RToken[1]);
    const UnitradeJob = await UnitradeRelay3r.deployed();
    //Add to jobs on keeper token
    await keeperTokenD.addJob(UnitradeJob.address);

    //Deploy keeper job registry
    await deployer.deploy(Keep3rV1JobRegistry);
    const KeeperJobRegistryD = await Keep3rV1JobRegistry.deployed();
    //Add existing jobs
    await KeeperJobRegistryD.add(
      YearnV1EarnKeep3rJob.address,
      "YearnV1EarnKeep3r",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/main/jobs/yearnv1earnkeeper.js"
    );
    await KeeperJobRegistryD.add(
      UniswapV2SlidingOracleJob.address,
      "UniswapV2SlidingOracle",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/main/jobs/uniswapv2slidingoracle.js"
    );
    await KeeperJobRegistryD.add(
      UnitradeJob.address,
      "UnitradeRelay3r",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/main/jobs/unitraderelay3r.js"
    );
    await KeeperJobRegistryD.add(
      SushiswapV2Keep3rJob.address,
      "SushiswapV2Keep3r",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/main/jobs/sushiswapkeep3r.js"
    );

    //First approve token contract to spend token
    await keeperTokenD.approve(Addrs.RL3RToken[1], InitiaLSupply);

    // console.log(await keeperTokenD.balanceOf("0xAa9E20bAb58d013220D632874e9Fe44F8F971e4d"))

    //Add 10 RL3R on Unitrade Job
    await keeperTokenD.addCredit(
      Addrs.RL3RToken[1],
      UnitradeJob.address,
      Web3.utils.toWei("10", "ether")
    );
    //Add 8 RL3R on SushiswapV2Keep3r Job
    await keeperTokenD.addCredit(
      Addrs.RL3RToken[1],
      SushiswapV2Keep3rJob.address,
      Web3.utils.toWei("8", "ether")
    );
    //Add 12 RL3R on UniswapV2SlidingOracleJob Job
    await keeperTokenD.addCredit(
      Addrs.RL3RToken[1],
      UniswapV2SlidingOracleJob.address,
      Web3.utils.toWei("12", "ether")
    );
    //Add 10 RL3R on UniswapV2SlidingOracleJob Job
    await keeperTokenD.addCredit(
      Addrs.RL3RToken[1],
      YearnV1EarnKeep3rJob.address,
      Web3.utils.toWei("10", "ether")
    );
  }
  else{
    //Deploy governance
    // await deployer.deploy(Governance,"0xf771733a465441437EcF64FF410e261516c7c5F3");
  }
  // //Deploy lp helper
  // await deployer.deploy(TokenHelper);
  // await deployer.link(TokenHelper, GetKP3RLPs);
  // await deployer.deploy(GetKP3RLPs, Addrs.UniRouter[1], Addrs.RL3RToken[1]);
};
