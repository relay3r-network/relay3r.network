var Web3 = require("web3");
const helper = require("./helpers/truffleTestHelper");

//Core contracts
const Keep3rV1Library = artifacts.require("Keep3rV1Library");
const Relay3rV2 = artifacts.require("Relay3rV2");
const Keep3rV1HelperMock = artifacts.require("Keep3rV1HelperMock");
//Jobs
const WrappedKeep3rRelayer = artifacts.require("WrappedKeep3rRelayer");
const MockJob = artifacts.require("MockJob");

//Global vars
//Tokens
var RLR, KP3R;
//libs
var kp3rlib, kp3rlibn;
//Helpers
var HelperD, HelperD2;
//jobs
var MockJobD, WrappedKeep3rRelayerD;
describe("WrappedKeep3rRelayer Tests", async function () {
  it("Deploy RLR", async () => {
    // Deploy RLR
    kp3rlib = await Keep3rV1Library.new();
    await Relay3rV2.link("Keep3rV1Library", kp3rlib.address);
    RLR = await Relay3rV2.new();
    assert(RLR.address !== "");
    //Mint initial supply for us
    await RLR.mint(Web3.utils.toWei("20000", "ether"));

    //Deploy and set mock helper
    HelperD = await Keep3rV1HelperMock.new();
    HelperD.setToken(RLR.address);
    await RLR.setKeep3rHelper(HelperD.address);
  });
  it("Deploy KP3R", async () => {
    //Deploy KP3r
    kp3rlibn = await Keep3rV1Library.new();
    await Relay3rV2.link("Keep3rV1Library", kp3rlibn.address);
    KP3R = await Relay3rV2.new();
    //Deploy and set helper
    HelperD2 = await Keep3rV1HelperMock.new();
    HelperD.setToken(KP3R.address);
    await KP3R.setKeep3rHelper(HelperD2.address);
  });
  it("Deploy MockJob KP3r", async () => {
    MockJobD = await MockJob.new(KP3R.address);
    //Add job
    await KP3R.addJob(MockJobD.address);
    //Add credits for mock job
    await KP3R.addRLRCredit(MockJobD.address, Web3.utils.toWei("100", "ether"));
  });
  it("Deploy WrappedKeep3rRelayer", async () => {
    //Deploy and add wrapped keeper relayer job
    WrappedKeep3rRelayerD = await WrappedKeep3rRelayer.new(
      KP3R.address,
      RLR.address
    );
    await RLR.addJob(WrappedKeep3rRelayerD.address);
    await RLR.addRLRCredit(
      WrappedKeep3rRelayerD.address,
      Web3.utils.toWei("100", "ether")
    );
  });
  it("Prepare relayer", async () => {
    //Bond 250 tokens
    await RLR.bond(RLR.address, Web3.utils.toWei("200", "ether"));
    //Advance 3 days
    await helper.advanceTimeAndBlock(259200);
    //Activate RLR bonds
    await RLR.activate(RLR.address);

    //Check owner is relayer
    assert(RLR.keepers(await RLR.governance()));
  });
});
