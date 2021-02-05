var Web3 = require("web3");

//Keeoer core contracts
const Keep3rV1HelperLegacyV1 = artifacts.require("Keep3rV1HelperLegacyV1");
const Keep3rV1HelperMock = artifacts.require("Keep3rV1HelperMock");

const Keep3rV1Library = artifacts.require("Keep3rV1Library");
const Relay3rV3 = artifacts.require("Relay3rV3");
const Keep3rV1JobRegistry = artifacts.require("Keep3rV1JobRegistry");
const Keep3rV1HelperNewCustom = artifacts.require("Keep3rV1HelperNewCustom");

//Jobs
const UnitradeExecutorRLRV7 = artifacts.require("UnitradeExecutorRLRV7");
const RelayerV1OracleCustom = artifacts.require("RelayerV1OracleCustom");

const Addrs = require("../constants/constants").Addrs;

/* Various deploy stages */
const InitialDeployWithMigrator = false;
const DeployLegacyHelper = false;
const DeployNewUnitradeJob = false;
const DeployRelayerV1Oracle = false;
const DeployNewHelper = false;
const DeployOnRopsten = false;
const DeployMockHelper = false;

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
/*
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
*/
    //Add to jobs on keeper token
    await RelayerTokenD.addJob(RelayerV1OracleCustomJob.address);

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

    //Add 50 RLR on RelayerV1OracleCustom Job
    await RelayerTokenD.addRLRCredit(
      RelayerV1OracleCustomJob.address,
      Web3.utils.toWei("500", "ether")
    );

    //Deploy helper
    await deployer.deploy(
      Keep3rV1HelperNewCustom,
      RelayerTokenD.address,
      RelayerV1OracleCustomJob.address
    );
    const helperNew = await Keep3rV1HelperNewCustom.deployed();
    await RelayerTokenD.setKeep3rHelper(helperNew.address);
  } else if (DeployOnRopsten) {
    //Deploy v3 token
    await deployer.deploy(Keep3rV1Library);
    await deployer.link(Keep3rV1Library, Relay3rV3);
    await deployer.deploy(Relay3rV3);
    const RelayerTokenD = await Relay3rV3.deployed();
    const InitiaLSupply = Web3.utils.toWei("94538", "ether");
    //Mint initial supply
    await RelayerTokenD.mint(InitiaLSupply); //94,538 RLR
    await deployer.deploy(Keep3rV1HelperLegacyV1);
    KPRH = await Keep3rV1HelperLegacyV1.deployed();
    await KPRH.setToken(RelayerTokenD.address);
    await RelayerTokenD.setKeep3rHelper(KPRH.address);
  } else if (DeployMockHelper) {
    const RelayerTokenD = await Relay3rV3.at(
      "0xB9dF1319250AaE181B48ef0C04E698885b47d693"
    );
    await deployer.deploy(Keep3rV1HelperMock);
    KPRH = await Keep3rV1HelperMock.deployed();
    await KPRH.setToken("0xB9dF1319250AaE181B48ef0C04E698885b47d693");
    await RelayerTokenD.setKeep3rHelper(KPRH.address);
  } else if (DeployLegacyHelper) {
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    await deployer.deploy(Keep3rV1HelperLegacyV1);
    const keeperHelperD = await Keep3rV1HelperLegacyV1.deployed();
    await RelayerTokenD.setKeep3rHelper(keeperHelperD.address);
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
    const helperNew = await Keep3rV1HelperNewCustom.at(
      "0x95e7F7c9F4dF96B92cb470F4C0cEA41de97662ae"
    );
    await helperNew.setOracle(RelayerV1OracleJob.address);
    //await RelayerTokenD.setKeep3rHelper(helperNew.address);
  } else if (DeployNewHelper) {
    const RelayerTokenD = await Relay3rV3.at(Addrs.RLRToken[1]);
    await deployer.deploy(
      Keep3rV1HelperNewCustom,
      RelayerTokenD.address,
      Addrs.UniRLROracle[1]
    );
    const helperNew = await Keep3rV1HelperNewCustom.deployed();
    await RelayerTokenD.setKeep3rHelper(helperNew.address);
  }
};
