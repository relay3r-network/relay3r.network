var Tx = require("ethereumjs-tx").Transaction;
const Web3 = require("web3");
const provider = new Web3.providers.HttpProvider("Enter rpc url here");
const web3 = new Web3(provider);
const axios = require("axios").default;
const hegicabi = require("./abis/hegic.json");
const account = "enter ethereum publickeyhere";
web3.eth.defaultAccount = account;

const privateKey = Buffer.from("Enter ethereum private key here", "hex");

const abi = hegicabi;

const address = "0x5DDe926b0A31346f2485900C5e64c2577F43F774";
const job = new web3.eth.Contract(abi, address);

_getGasPrice();

function _getGasPrice() {
  axios
    .get("https://gasprice.poa.network/")
    .then((resp) => {
      job.methods.workable().call({ from: account }, function (error, result) {
        if (result) {
          work(resp.data.instant);
        } else {
          setTimeout(_getGasPrice, 300000);
        }
      });
    })
    .catch((err) => {
      console.log(err);
      setTimeout(_getGasPrice, 300000);
    });
}

function work(gwei) {
  web3.eth.getTransactionCount(account, (err, txCount) => {
    // Build the transaction
    const txObject = {
      nonce: web3.utils.toHex(txCount),
      to: address,
      value: web3.utils.toHex(web3.utils.toWei("0", "ether")),
      gasLimit: web3.utils.toHex(1000000),
      gasPrice: web3.utils.toHex(web3.utils.toWei("" + gwei, "gwei")),
      data: job.methods.claimRewards().encodeABI(),
    };
    // Sign the transaction
    const tx = new Tx(txObject);
    tx.sign(privateKey);

    const serializedTx = tx.serialize();
    const raw = "0x" + serializedTx.toString("hex");

    // Broadcast the transaction
    const transaction = web3.eth.sendSignedTransaction(raw, (err, tx) => {
      console.log(tx);
    });
  });
  setTimeout(_getGasPrice, 300000);
}
