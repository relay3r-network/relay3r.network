var Web3 = require("web3");
const truffleAssert = require("truffle-assertions");

const helper = require("./helpers/truffleTestHelper");

//Core contracts
const Keep3rV1Library = artifacts.require("Keep3rV1Library");
const Relay3rV3 = artifacts.require("Relay3rV3");
const Keep3rV1HelperMock = artifacts.require("Keep3rV1HelperMock");
//Distributor
const KeeperBonderDistributor = artifacts.require("KeeperBonderDistributor");

//Global vars
//Tokens
var RLR;
//libs
var kp3rlib;
//Helpers
var HelperD;
var Distributor;
//Accounts
var accounts, owner;

contract("KeeperBonderDistributor", async function () {
  it("Deploy RLR", async () => {
    //Init accs
    accounts = await web3.eth.getAccounts();
    owner = accounts[0];
    // Deploy RLR
    kp3rlib = await Keep3rV1Library.new();
    await Relay3rV3.link("Keep3rV1Library", kp3rlib.address);
    RLR = await Relay3rV3.new();
    assert(RLR.address !== "");
    //Mint initial supply for us
    await RLR.mint(Web3.utils.toWei("20000", "ether"));

    //Deploy and set mock helper
    HelperD = await Keep3rV1HelperMock.new();
    HelperD.setToken(RLR.address);
    await RLR.setKeep3rHelper(HelperD.address);
  });
  it("Deploy KeeperBonderDistributor", async () => {
    // Deploy RLR
    Distributor = await KeeperBonderDistributor.new(RLR.address);
    assert(Distributor.address !== "");
  });

  describe("KeeperBonderDistributor dist tests", async function () {
    it("Bond and activate relayers", async () => {
      //Bond 250 tokens
      await RLR.bond(RLR.address, Web3.utils.toWei("200", "ether"));
      //Advance 3 days
      await helper.advanceTimeAndBlock(259200);
      //Activate RLR bonds
      await RLR.activate(RLR.address);
      //Transfer 100 of them to our alt address
      await RLR.transferKeeperRight(RLR.address, owner, accounts[1], Web3.utils.toWei("100", "ether"))
      //Check owner is relayer
      assert(await RLR.keepers(await RLR.governance()));
      //Check alt acc is relayer
      assert(await RLR.keepers(accounts[1]));
      //Check that postive relayers count is 2
      assert(await Distributor.getPositiveKeepersCount() == 2,`Invalid positive relayers count ${await Distributor.getPositiveKeepersCount()}`)
    });

    it("Distribute ETH to relayers", async () => {
        let altETHBal = await web3.eth.getBalance(accounts[1]);
        //Send 1 eth to distributor
        await Distributor.send(Web3.utils.toWei("1", "ether"));
        //Call distributeETH
        await Distributor.distributeETH();
        //Check ending balance of distributor eth is 0
        assert(await web3.eth.getBalance(Distributor.address) == 0,`Distribute didnt distribute all,eth bal : ${await web3.eth.getBalance(Distributor.address)}`)
        //Check if eth was sent in proportion
        assert(await web3.eth.getBalance((accounts[1])) - altETHBal == Web3.utils.toWei("0.5", "ether"),`!proportion ${await web3.eth.getBalance(accounts[1])}`);
    })
    it("Distribute Token to relayers", async () => {
        let altRLRBal = await RLR.balanceOf(accounts[1]);
        //Send 100 rlr to distributor
        await RLR.transfer(Distributor.address,Web3.utils.toWei("100", "ether"));
        //Call distributeTokens
        await Distributor.distributeToken(RLR.address);
        //Check ending balance of distributor RLR is 0
        assert(await await RLR.balanceOf(Distributor.address) == 0,`Distribute didnt distribute all,RLR Token bal : ${await web3.eth.getBalance(Distributor.address)}`)
        //Check if tokens was sent in proportion
        assert(await await RLR.balanceOf((accounts[1])) - altRLRBal == Web3.utils.toWei("50", "ether"),`!proportion ${await RLR.balanceOf(accounts[1])}`);
    })
  });
});
