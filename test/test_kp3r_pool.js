var Web3 = require("web3");
const helper = require("./helpers/truffleTestHelper");

//Core contracts
const Keep3rV1Library = artifacts.require("Keep3rV1Library");
const Relay3rV2 = artifacts.require("Relay3rV2");
const Keep3rV1HelperMock = artifacts.require("Keep3rV1HelperMock");
//Jobs
const WrappedKeep3rRelayer = artifacts.require("WrappedKeep3rRelayer");
const MockJob = artifacts.require("MockJob");
const MockMetaKeep3r = artifacts.require("MockMetaKeep3r");

//Global vars
//Tokens
var RLR, KP3R;
//libs
var kp3rlib, kp3rlibn;
//Helpers
var HelperD, HelperD2;
//jobs
var MockJobD, WrappedKeep3rRelayerD,MockMetaKeep3rD;
//Accounts
var accounts, owner;
function relDiff(a, b) {
  return 100 * Math.abs((a - b) / ((a + b) / 2));
}

contract("WrappedKeep3rRelayer", async function () {
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
  it("Deploy KP3R", async () => {
    //Deploy KP3r
    kp3rlibn = await Keep3rV1Library.new();
    await Relay3rV2.link("Keep3rV1Library", kp3rlibn.address);
    KP3R = await Relay3rV2.new();
    //Mint initial supply for us
    await KP3R.mint(Web3.utils.toWei("20000", "ether"));
    //Deploy and set helper
    HelperD2 = await Keep3rV1HelperMock.new();
    HelperD2.setToken(KP3R.address);
    await KP3R.setKeep3rHelper(HelperD2.address);
  });
  it("Deploy MockJob KP3r", async () => {
    MockJobD = await MockJob.new(KP3R.address);
    //Add job
    await KP3R.addJob(MockJobD.address);
    //Add credits for mock job
    await KP3R.addRLRCredit(MockJobD.address, Web3.utils.toWei("100", "ether"));
  });
  it("Deploy MockMetaKeep3r", async () => {
    MockMetaKeep3rD = await MockMetaKeep3r.new(KP3R.address);
    //Add job
    await KP3R.addJob(MockMetaKeep3rD.address);
    // add 100 kp3r to job
    await KP3R.addRLRCredit(MockMetaKeep3rD.address,Web3.utils.toWei("100", "ether"));
    //send mock metakeep3r 10 eth to pay as rewards to emulate the swap
    await MockMetaKeep3rD.send(Web3.utils.toWei("10", "ether"));
    //Activate metakeep3r by adding 0 votes to metakeep3r addr
    await KP3R.addVotes(MockMetaKeep3rD.address,0);
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
  it("Prepare keeper", async () => {
    //Bond 250 tokens
    await KP3R.bond(KP3R.address, Web3.utils.toWei("250", "ether"));
    //Advance 3 days
    await helper.advanceTimeAndBlock(259200);
    //Activate RLR bonds
    await KP3R.activate(KP3R.address);

    //Check owner is keeper
    assert(KP3R.keepers(await KP3R.governance()));
  });
  it("Send target KP3R to Pool", async () => {
    //Approve first
    await KP3R.approve(
      WrappedKeep3rRelayerD.address,
      Web3.utils.toWei("250", "ether")
    );
    //Deposit it
    await WrappedKeep3rRelayerD.deposit(Web3.utils.toWei("250", "ether"));
  });

  it("Bond and activate pool", async () => {
    //Deposit it
    await WrappedKeep3rRelayerD.bondBalance();
    //Advance 3 days
    await helper.advanceTimeAndBlock(259200);
    //Activate bonds
    await WrappedKeep3rRelayerD.activateBonds();
    const bondBalance = await WrappedKeep3rRelayerD.getBondedBalance();
    //Check bond after activation is 250 KP3R
    assert(
      bondBalance.toString() === Web3.utils.toWei("250", "ether"),
      `Bond doesnt match target : ${bondBalance}`
    );
  });
  it("Proxy Job execution", async () => {
    const bondBalanceBef = await WrappedKeep3rRelayerD.getBondedBalance();
    const workCall = MockJobD.contract.methods.work().encodeABI();
    const proxyCall = await WrappedKeep3rRelayerD.executeCall(
      MockJobD.address,
      workCall
    );
    const bondBalance = await WrappedKeep3rRelayerD.getBondedBalance();
    const proxyContractprofit = bondBalance - bondBalanceBef;
    // Obtain gasPrice from the transaction
    const tx = await web3.eth.getTransaction(proxyCall.tx);
    const totalCost1 = tx.gasPrice * proxyCall.receipt.gasUsed;

    // console.log(`Total tx Cost : ${totalCost1 / 1e18} ETH `)
    // console.log(`Total KP3R Reward : ${proxyContractprofit/ 1e18 } KP3R `)
    assert(
      bondBalance > parseInt(Web3.utils.toWei("250", "ether")),
      `Bond balance on proxy hasn't increased : ${
        proxyContractprofit / 1e18
      } KP3R`
    );
    /*
    // console.log(`KP3R Per eth spent ${totalCost1/proxyContractprofit }`)

    //Check bond after execution is > 250 KP3R


    //Check if its more profitable than running it outselves
    const ourbonds = await KP3R.bonds(await KP3R.governance(),KP3R.address);
    const proxyCall2 = await MockJobD.work();
    const ourbondsnew = await KP3R.bonds(await KP3R.governance(),KP3R.address);
    const ourProfit = ourbondsnew - ourbonds;
    const tx2 = await web3.eth.getTransaction(proxyCall2.tx);
    const totalCost = tx2.gasPrice * proxyCall2.receipt.gasUsed;
    console.log(`Total tx Cost : ${ totalCost/ 1e18} ETH `)
    console.log(`Total KP3R Reward : ${ourProfit/ 1e18 } KP3R `)
    // console.log(`KP3R Per eth spent ${totalCost/ourProfit}`)
    // assert (totalCost/ourProfit < totalCost1/proxyContractprofit,`We are more profitable by ${relDiff((totalCost1/proxyContractprofit),(totalCost/ourProfit))}`)
    */
  });
  it("Direct MetaKeep3r Job execution", async () => {
    const currentETHBalance = await web3.eth.getBalance(owner);
    //first get encoded bytes to call to metakeep3r,then call it to wrapped relayer
    //Metakeep3r call
    await MockMetaKeep3rD.work(MockJobD.address);
    const afterETHBalance = await web3.eth.getBalance(owner);
    assert(
      afterETHBalance > currentETHBalance,
      `ETH Balance hasn't increased : ${
        afterETHBalance - currentETHBalance / 1e18
      } ETH diff`
    );
  })
  
  it("Proxy MetaKeep3r Job execution", async () => {
    const currentETHBalance = await web3.eth.getBalance(WrappedKeep3rRelayerD.address);
    const workCall = MockJobD.contract.methods.work().encodeABI();
    //first get encoded bytes to call to metakeep3r,then call it to wrapped relayer
    //Metakeep3r call
    const calldata = await MockMetaKeep3rD.contract.methods.task(MockJobD.address,workCall).encodeABI()
    await WrappedKeep3rRelayerD.executeCall(MockMetaKeep3rD.address,calldata);
    const afterETHBalance = await web3.eth.getBalance(WrappedKeep3rRelayerD.address);

    // console.log(`Total tx Cost : ${totalCost1 / 1e18} ETH `)
    // console.log(`Total KP3R Reward : ${proxyContractprofit/ 1e18 } KP3R `)
    assert(
      afterETHBalance > currentETHBalance,
      `ETH Balance hasn't increased : ${
        afterETHBalance - currentETHBalance / 1e18
      } ETH diff`
    );
  })

});
