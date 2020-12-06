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
var RLR;
//libs
var kp3rlib;
//Helpers
var HelperD;
//jobs
var MockJobD;
//Accounts
var accounts, owner;

contract("Relayer functional", async function () {
  it("Deploy RLR", async () => {
    //Init accs
    accounts = await web3.eth.getAccounts();
    owner = accounts[0];
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

  it("Deploy MockJob KP3r", async () => {
    MockJobD = await MockJob.new(RLR.address);
    //Add job
    await RLR.addJob(MockJobD.address);
    //Add credits for mock job
    await RLR.addRLRCredit(MockJobD.address, Web3.utils.toWei("100", "ether"));
  });
  describe("Relayer bonds", async function () {
    it("Bond and activate relayer", async () => {
      //Bond 250 tokens
      await RLR.bond(RLR.address, Web3.utils.toWei("200", "ether"));
      //Advance 3 days
      await helper.advanceTimeAndBlock(259200);
      //Activate RLR bonds
      await RLR.activate(RLR.address);

      //Check owner is relayer
      assert(RLR.keepers(await RLR.governance()));
    });

    it("Unbond and withdraw bonds", async () => {
      //Unbon 200 tokens
      await RLR.unbond(RLR.address, Web3.utils.toWei("200", "ether"));
      //Advance 14 days
      await helper.advanceTimeAndBlock(1.21e6);
      //Activate RLR bonds
      await RLR.withdraw(RLR.address);

      let remainbonds = await RLR.bonds(owner, RLR.address);
      let ownerIsRelayer = await RLR.keepers(owner);
      //Check owner is still relayer
      assert(ownerIsRelayer, "Lost relayer rights after unbond and withdraw");
      //Check bonds after unbond is 0
      assert(remainbonds == 0, `Not 0 bonds remain ${remainbonds}`);
    });

    it("Execute work and check reward", async () => {
      let owner = await RLR.governance();
      let currbond = await RLR.bonds(owner, RLR.address);
      await MockJobD.work();
      let newbond = await RLR.bonds(owner, RLR.address);
      //Check we got rewarded for the work
      assert(newbond > currbond, `No Rewards gotten on work ${newbond}`);
    });
  });

  describe("Relayer rights", async function () {
    it("Partial relayer rights transfer from caller", async () => {
      //Transfer full bonds and rights to new address
      let currBond = await RLR.bonds(owner, RLR.address);
      //Take some away to make it partial transfer
      currBond -= 10;
      //Transfer partially
      await RLR.transferKeeperRight(RLR.address, owner, accounts[1], currBond);
      let ownerIsRelayer = await RLR.keepers(owner);
      assert(ownerIsRelayer, "Lost rights after partial transfer");
    });

    it("Transfer relayer rights from caller", async () => {
      //Transfer full bonds and rights to new address
      let currBond = await RLR.bonds(owner, RLR.address);
      await RLR.transferKeeperRight(RLR.address, owner, accounts[1], currBond);
      let ownerIsRelayer = await RLR.keepers(owner);
      assert(!ownerIsRelayer, "Still has relayer rights after full transfer");
    });

    it("Transfer relayer rights from new addr to owner", async () => {
      //Transfer full bonds and rights to new address
      let currBond = await RLR.bonds(accounts[1], RLR.address);
      await RLR.transferKeeperRight(RLR.address, accounts[1], owner, currBond, {
        from: accounts[1],
      });
      let originIsRelayer = await RLR.keepers(accounts[1]);
      let ownerIsRelayer = await RLR.keepers(owner);
      assert(!originIsRelayer, "Caller still relayer");
      assert(ownerIsRelayer, "Did not get rights after transfer back");
    });

    it("Transfer relayer rights with approval", async () => {
      //Transfer full bonds and rights to new address
      let currBond = await RLR.bonds(owner, RLR.address);
      const approveret = await RLR.keeperrightapprove(
        accounts[1],
        RLR.address,
        currBond
      );
      assert(approveret, "Approve failed");
      await RLR.transferKeeperRight(RLR.address, owner, accounts[1], currBond, {
        from: accounts[1],
      });
      let originIsRelayer = await RLR.keepers(accounts[1]);
      let ownerIsRelayer = await RLR.keepers(owner);
      assert(originIsRelayer, "Destination is not relayer");
      assert(!ownerIsRelayer, "Origin still has rights");
      //Check remaining allowance is 0
      let remainingAllowance = await RLR.KeeperAllowances(
        owner,
        accounts[1],
        RLR.address
      );
      assert(
        remainingAllowance == 0,
        "Full transfer doesnt set allowance to 0"
      );
    });
  });

  describe("Variable bonding delays", async function () {
    it("Set new bonding delay", async () => {
      //Get current unbonding delay
      let curbond = await RLR.BOND();
      //Set new bond delay as half of current bond delay
      await RLR.setNewDelay(curbond / 2, 1);
      let newbond = await RLR.BOND();
      assert(curbond / 2 == newbond, "Bond delay not changed");
    });
    it("Set new unbonding delay", async () => {
      //Get current unbonding delay
      let curunbond = await RLR.UNBOND();
      //Set new unbond delay as half of current unbond delay
      await RLR.setNewDelay(curunbond / 2, 2);
      let newunbond = await RLR.UNBOND();
      assert(curunbond / 2 == newunbond, "Unbond delay not changed");
    });
    it("Set new liquidity bonding delay", async () => {
      //Get current unbonding delay
      let curliqbond = await RLR.LIQUIDITYBOND();
      //Set new bond delay as half of current bond delay
      await RLR.setNewDelay(curliqbond / 2, 3);
      let newbond = await RLR.LIQUIDITYBOND();
      assert(curliqbond / 2 == newbond, "LiqBond delay not changed");
    });
  });
});
