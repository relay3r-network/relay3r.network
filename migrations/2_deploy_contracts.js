var Web3 = require("web3");

//Keeoer core contracts
const Keep3rV1HelperLegacyV1 = artifacts.require("Keep3rV1HelperLegacyV1");
const Keep3rV1Library = artifacts.require("Keep3rV1Library");
const Relay3rV3 = artifacts.require("Relay3rV3");
const Keep3rV1JobRegistry = artifacts.require("Keep3rV1JobRegistry");
const Keep3rV1HelperNewCustom = artifacts.require("Keep3rV1HelperNewCustom");
//Extra contracts
// const Governance = artifacts.require("Governance")
//Migration contracts
const TokenMigrator = artifacts.require("TokenMigratorCustomizable");
const LiqMigratorNew = artifacts.require("LiqMigratorNew");
//Mock testing token contract
const BurnableToken = artifacts.require("BurnableToken");
//Liquidty rewards
const RlrUniRewards = artifacts.require("RlrUniRewards");
const RlrMooniRewards = artifacts.require("RlrMooniRewards");

//Jobs
const UnitradeExecutorRLRV7 = artifacts.require("UnitradeExecutorRLRV7");
const CoreFlashArbRelayerV3 = artifacts.require("CoreFlashArbRelayerV3");
const GetBackETHRelayer = artifacts.require("GetBackETHRelayer");
const BACFarmerRelayer = artifacts.require("BACFarmerRelayerv3");
const RelayerV1OracleCustom = artifacts.require("RelayerV1OracleCustom");
const SynlRebalancer = artifacts.require("SynlRebalancer");
const TrinityAlchemizer = artifacts.require("TrinityAlchemizer");
//LP contracts
// const GetRL3RLPs = artifacts.require("GetRelay3rLPTokens");
// const TokenHelper = artifacts.require("TokenHelper");

const Addrs = require("../constants/constants").Addrs;

/* Various deploy stages */
const InitialDeployWithMigrator = false;
const DeployLiqMigrator = false;
const DeployLegacyHelper = false;
const DeployNewCoreJob = false;
const DeployNewUnitradeJob = false;
const DeployGBETHJob = false;
const DeployBACFarmerJob = false;
const DeployLiqMiner = false;
const DeployCHIJobs = false;
const DeployRelayerV1Oracle = false;
const DeployNewHelper = false;
const testLiqMinerPhase = false;
const DeploySynlRebalancer = false;
const DeployTrinityAlchemizer = false;
const DeployLidoRelayer = false;

module.exports = async function (deployer) {
   // Deploy token with library
   if (InitialDeployWithMigrator) {
    //Deploy v3 token
    await deployer.deploy(Keep3rV1Library);
    await deployer.link(Keep3rV1Library, Relay3rV3);
    await deployer.deploy(Relay3rV3);
    const RelayerTokenD = await Relay3rV3.deployed();

    const InitiaLSupply = Web3.utils.toWei("94538", "ether");
    //Mint initial supply
    await RelayerTokenD.mint(InitiaLSupply); //94,538 RLR

    //Deploy RelayerV1OracleCustom
    await deployer.deploy(RelayerV1OracleCustom, RelayerTokenD.address);
    const RelayerV1OracleCustomJob = await RelayerV1OracleCustom.deployed();

    //Deploy UnitradeJob
    await deployer.deploy(UnitradeExecutorRLRV7, RelayerTokenD.address);
    const UnitradeJob = await UnitradeExecutorRLRV7.deployed();

    //Deploy GetBackETHRelayer
    await deployer.deploy(
      GetBackETHRelayer,
      RelayerTokenD.address,
      Addrs.GetBackETHHelperV2[1]
    );
    const GetBackETHRelayerJob = await GetBackETHRelayer.deployed();
    //Add to jobs on keeper token
    await RelayerTokenD.addJob(RelayerV1OracleCustomJob.address);
    await RelayerTokenD.addJob(UnitradeJob.address);
    await RelayerTokenD.addJob(GetBackETHRelayerJob.address);

    //Deploy keeper job registry
    await deployer.deploy(Keep3rV1JobRegistry);
    const KeeperJobRegistryD = await Keep3rV1JobRegistry.deployed();

    //Add job data
    await KeeperJobRegistryD.add(
      RelayerV1OracleCustomJob.address,
      "RelayerV1OracleCustom",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/main/src/jobs/RelayerV1OracleJob.js"
    );

    //Add to registry
    await KeeperJobRegistryD.add(
      GetBackETHRelayerJob.address,
      "GetBackETHRelayer",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/new-combined/src/jobs/relayer/GetBackETHRelayerJob.js"
    );
    await KeeperJobRegistryD.add(
      UnitradeJob.address,
      "UnitradeExecutorRLRV7",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/main/src/jobs/unitraderelay3r.js"
    );

    //Add 5 RLR on Unitrade Job
    await RelayerTokenD.addRLRCredit(
      UnitradeJob.address,
      Web3.utils.toWei("150", "ether")
    );
    //Add 12 RLR on GetBackETHRelayerJob Job
    await RelayerTokenD.addRLRCredit(
      GetBackETHRelayerJob.address,
      Web3.utils.toWei("150", "ether")
    );
    //Add 50 RLR on RelayerV1OracleCustom Job
    await RelayerTokenD.addRLRCredit(
      RelayerV1OracleCustomJob.address,
      Web3.utils.toWei("50", "ether")
    );

    //Deploy helper
    await deployer.deploy(Keep3rV1HelperNewCustom,RelayerTokenD.address, RelayerV1OracleCustomJob.address);
    const helperNew = await Keep3rV1HelperNewCustom.deployed();
    await RelayerTokenD.setKeep3rHelper(helperNew.address);

    //Deploy migrator
    await deployer.deploy(TokenMigrator, Addrs.RLRToken[1], RelayerTokenD.address);
    const TokenMigratorD = await TokenMigrator.deployed();
    //Now send supply of relayer tokens to migrator
    await RelayerTokenD.transfer(
      TokenMigratorD.address,
      Web3.utils.toWei("94538", "ether")
    );
    //Deploy liq migrator
    await deployer.deploy(LiqMigratorNew, TokenMigratorD.address, Addrs.RLRETHPair[1]);
    const LiqMigratorD = await LiqMigratorNew.deployed();
    //Transfer ownership of the migrator to liqmigrator
    await TokenMigratorD.transferOwnership(LiqMigratorD.address);

  } else if (DeployLegacyHelper) {
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    await deployer.deploy(Keep3rV1HelperLegacyV1);
    const keeperHelperD = await Keep3rV1HelperLegacyV1.deployed();
    await RelayerTokenD.setKeep3rHelper(keeperHelperD.address);
  } else if (DeployNewCoreJob) {
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    const KeeperJobRegistryD = await Keep3rV1JobRegistry.at(
      Addrs.Keep3rV1JobRegistry[1]
    );

    //Deploy CoreFlashArbRelay3rNew
    await deployer.deploy(
      CoreFlashArbRelayerV3,
      RelayerTokenD.address,
      Addrs.CoreFlashArb[1],
      Addrs.CoreToken[1]
    );
    const CoreFlashArbRelayerV3Job = await CoreFlashArbRelayerV3.deployed();
    //Remove old job
    await RelayerTokenD.removeJob("0x7905AAE5E92D9Ff324d0b2Ae5220e2Bb0078553a");
    //Add to jobs on keeper token
    await RelayerTokenD.addJob(CoreFlashArbRelayerV3Job.address);
    //Add 1 RLR on CoreFlashArbRelay3rNew Job
    await RelayerTokenD.addRLRCredit(
      CoreFlashArbRelayerV3Job.address,
      Web3.utils.toWei("1", "ether")
    );
    //Add to registry
    await KeeperJobRegistryD.add(
      CoreFlashArbRelayerV3Job.address,
      "CoreFlashArbRelayerV3",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/main/src/jobs/coreflasharbrelay3r.js"
    );
  } else if (DeployLiqMiner) {
    //Init RLR Interface
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    //Deploy uniswap reward contract
    await deployer.deploy(RlrUniRewards);
    const RlrUniMine = await RlrUniRewards.deployed();
    // //Deploy mooniswap reward contract
    // await deployer.deploy(RlrMooniRewards);
    // const RlrMooniMine = await RlrMooniRewards.deployed();
    //Follow mainnet procedure
    //Send 4450 RLR to UniPool Rewards
    // RelayerTokenD.transfer(
    //   RlrUniMine.address,
    //   Web3.utils.toWei("4450", "ether")
    // );
    // //Send 4450 RLR to MooniPool Rewards
    // RelayerTokenD.transfer(
    //   RlrMooniMine.address,
    //   Web3.utils.toWei("4450", "ether")
    // );
    //Init slow rewards on both pools
    await RlrUniMine.initRewardSlow();
    // await RlrMooniMine.initRewardSlow();
  } else if (testLiqMinerPhase) {
    //Deploy uniswap reward contract
    await deployer.deploy(RlrUniRewards);
    const RlrUniMine = await RlrUniRewards.deployed();
    //deploy token to add liq to
    await deployer.deploy(BurnableToken, "RelayerReward", "RLRW");
    const Token1 = await BurnableToken.deployed();

    await deployer.deploy(BurnableToken, "RLRMockLP", "RLP");
    const TokenLP = await BurnableToken.deployed();

    //Set reward token
    await RlrUniMine.setRewardToken(Token1.address);
    await RlrUniMine.setLPToken(TokenLP.address);
    //Mint 89k tokens to transfer to rewards
    await Token1.mint(Web3.utils.toWei("4450", "ether"));
    //Now transfer 89k tokens of token1 to reward pool
    await Token1.transfer(
      RlrUniMine.address,
      Web3.utils.toWei("4450", "ether")
    );
    //Init slow rewardrate
    await RlrUniMine.initRewardSlow();
    // //Init normal reward rate
    // await RlrUniMine.initReward();
  } else if (DeployBACFarmerJob) {
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    const KeeperJobRegistryD = await Keep3rV1JobRegistry.at(
      Addrs.Keep3rV1JobRegistry[1]
    );
    //Deploy BACFarmerRelayer
    await deployer.deploy(
      BACFarmerRelayer,
      RelayerTokenD.address,
      Addrs.BACFarmer[1]
    );

    const BACFarmerRelayerJob = await BACFarmerRelayer.deployed();
    //Add to jobs on keeper token
    await RelayerTokenD.addJob(BACFarmerRelayerJob.address);
    //Add 50 RLR on BACFarmerRelayer Job
    await RelayerTokenD.addRLRCredit(
      BACFarmerRelayerJob.address,
      Web3.utils.toWei("50", "ether")
    );
    //Add to registry
    await KeeperJobRegistryD.add(
      BACFarmerRelayerJob.address,
      "BACFarmerRelayerv3",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/new-combined/src/jobs/relayer/BACFarmerRelayerJob.js"
    );
  } else if (DeployGBETHJob) {
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    const KeeperJobRegistryD = await Keep3rV1JobRegistry.at(
      Addrs.Keep3rV1JobRegistry[1]
    );

    //Deploy GetBackETHRelayer
    await deployer.deploy(
      GetBackETHRelayer,
      RelayerTokenD.address,
      Addrs.GetBackETHHelperV2[1]
    );

    const GetBackETHRelayerJob = await GetBackETHRelayer.deployed();
    //Add to jobs on keeper token
    await RelayerTokenD.addJob(GetBackETHRelayerJob.address);
    //Add 1 RLR on UnitradeExecutorRLRV7 Job
    await RelayerTokenD.addRLRCredit(
      GetBackETHRelayerJob.address,
      Web3.utils.toWei("50", "ether")
    );
    //Add to registry
    await KeeperJobRegistryD.add(
      GetBackETHRelayerJob.address,
      "GetBackETHRelayer",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/new-combined/src/jobs/relayer/GetBackETHRelayerJob.js"
    );
  } else if (DeployNewUnitradeJob) {
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    const KeeperJobRegistryD = await Keep3rV1JobRegistry.at(
      Addrs.Keep3rV1JobRegistry[1]
    );

    await RelayerTokenD.removeJob("0x09176410207689bf8727751633376a3bf7725791");

    //Deploy UnitradeExecutorRLRV7
    await deployer.deploy(UnitradeExecutorRLRV7, RelayerTokenD.address);

    const UnitradeExecutorRLRV7Job = await UnitradeExecutorRLRV7.deployed();
    //Add to jobs on keeper token
    await RelayerTokenD.addJob(UnitradeExecutorRLRV7Job.address);
    // //Add 1 RLR on UnitradeExecutorRLRV7 Job
    await RelayerTokenD.addRLRCredit(
      UnitradeExecutorRLRV7Job.address,
      Web3.utils.toWei("150", "ether")
    );
    //Add to registry
    await KeeperJobRegistryD.add(
      UnitradeExecutorRLRV7Job.address,
      "UnitradeExecutorRLRV7",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/new-combined/src/jobs/relayer/UnitradeRelayerJob.js"
    );
  } else if (DeployCHIJobs) {
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    const KeeperJobRegistryD = await Keep3rV1JobRegistry.at(
      Addrs.Keep3rV1JobRegistry[1]
    );
    //Remove old unitrade job
    await RelayerTokenD.removeJob("0x743bbe8416a9f1a6ff71d19f1e39F287C8225459");
    //Remove old corearb job
    await RelayerTokenD.removeJob("0x7A2369056c20270778651cba53F5A860ed2E29Cc");

    //Deploy UnitradeExecutorRLRV7
    await deployer.deploy(UnitradeExecutorRLRV7, RelayerTokenD.address);

    const UnitradeExecutorRLRV7Job = await UnitradeExecutorRLRV7.deployed();
    //Add to jobs on keeper token
    await RelayerTokenD.addJob(UnitradeExecutorRLRV7Job.address);
    // //Add 1 RLR on UnitradeExecutorRLRV7 Job
    await RelayerTokenD.addRLRCredit(
      UnitradeExecutorRLRV7Job.address,
      Web3.utils.toWei("50", "ether")
    );
    //Add to registry
    await KeeperJobRegistryD.add(
      UnitradeExecutorRLRV7Job.address,
      "UnitradeExecutorRLRV7",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/new-combined/src/jobs/relayer/UnitradeRelayerJob.js"
    );

    //Deploy CoreFlashArbRelayerV3
    await deployer.deploy(
      CoreFlashArbRelayerV3,
      RelayerTokenD.address,
      Addrs.CoreFlashArb[1]
    );

    const CoreFlashArbRelayerV3Job = await CoreFlashArbRelayerV3.deployed();
    //Add to jobs on keeper token
    await RelayerTokenD.addJob(CoreFlashArbRelayerV3Job.address);
    //Add 50 RLR on CoreFlashArbRelayerV3 Job
    await RelayerTokenD.addRLRCredit(
      CoreFlashArbRelayerV3Job.address,
      Web3.utils.toWei("50", "ether")
    );
    //Add to registry
    await KeeperJobRegistryD.add(
      CoreFlashArbRelayerV3Job.address,
      "CoreFlashArbRelayerV3",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/new-combined/src/jobs/relayer/CoreFlashArbRelayerJob.js"
    );
  } else if (DeployRelayerV1Oracle) {
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    const KeeperJobRegistryD = await Keep3rV1JobRegistry.at(
      Addrs.Keep3rV1JobRegistry[1]
    );
    // //Remove old relayer oracle job
    // await RelayerTokenD.removeJob("0xd5Cf1Cc695226B2243d7416Ec1B478577c50f2aF");

    //Deploy RelayerV1OracleCustom
    await deployer.deploy(RelayerV1OracleCustom, RelayerTokenD.address);

    const RelayerV1OracleJob = await RelayerV1OracleCustom.deployed();
    //Add to jobs on keeper token
    await RelayerTokenD.addJob(RelayerV1OracleJob.address);
    //Add 200 RLR on RelayerV1OracleCustom Job
    await RelayerTokenD.addRLRCredit(
      RelayerV1OracleJob.address,
      Web3.utils.toWei("200", "ether")
    );
    //Add to registry
    await KeeperJobRegistryD.add(
      RelayerV1OracleJob.address,
      "RelayerV1OracleCustom",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/new-combined/src/jobs/relayer/RelayerV1OracleJob.js"
    );
    const helperNew = await Keep3rV1HelperNewCustom.at("0x95e7F7c9F4dF96B92cb470F4C0cEA41de97662ae");
    await helperNew.setOracle(RelayerV1OracleJob.address);
    //await RelayerTokenD.setKeep3rHelper(helperNew.address);
  } else if (DeployNewHelper) {
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    await deployer.deploy(Keep3rV1HelperNewCustom,RelayerTokenD.address, Addrs.UniRLROracle[1]);
    const helperNew = await Keep3rV1HelperNewCustom.deployed();
    await RelayerTokenD.setKeep3rHelper(helperNew.address);
  }

  else if (DeploySynlRebalancer) {
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    const KeeperJobRegistryD = await Keep3rV1JobRegistry.at(
      Addrs.Keep3rV1JobRegistry[1]
    );
    //Deploy SynlRebalancer
    await deployer.deploy(SynlRebalancer,Addrs.RLRToken[1],Addrs.SYNL[1]);

    const SynlRebalancerJob = await SynlRebalancer.deployed();
    //Add to jobs on keeper token
    await RelayerTokenD.addJob(SynlRebalancerJob.address);
    //Add 200 RLR on SynlRebalancer Job
    await RelayerTokenD.addRLRCredit(
      SynlRebalancerJob.address,
      Web3.utils.toWei("200", "ether")
    );
    //Add to registry
    await KeeperJobRegistryD.add(
      SynlRebalancerJob.address,
      "SynlRebalancer",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/new-combined/src/jobs/relayer/SynlRebalancerJob.js"
    );
  }
  else if (DeployTrinityAlchemizer) {
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    const KeeperJobRegistryD = await Keep3rV1JobRegistry.at(
      Addrs.Keep3rV1JobRegistry[1]
    );
    //Deploy TrinityAlchemizer
    await deployer.deploy(TrinityAlchemizer,Addrs.RLRToken[1]);
    const TrinityAlchemizerJob = await TrinityAlchemizer.deployed();
    //Add to jobs on keeper token
    await RelayerTokenD.addJob(TrinityAlchemizerJob.address);
    //Add 200 RLR on TrinityAlchemizer Job
    await RelayerTokenD.addRLRCredit(
      TrinityAlchemizerJob.address,
      Web3.utils.toWei("200", "ether")
    );
    //Add to registry
    await KeeperJobRegistryD.add(
      TrinityAlchemizerJob.address,
      "TrinityAlchemizer",
      "",
      "https://github.com/relay3r-network/relay3r-jobs/blob/new-combined/src/jobs/relayer/TrinityAlchemizerJob.js"
    );
  }
};
