var Tx = require("ethereumjs-tx").Transaction;
const Web3 = require("web3");
const provider = new Web3.providers.HttpProvider("Enter rpc url here");
const web3 = new Web3(provider);
const axios = require("axios").default;
const uniswaporacleabi = require("./abis/uniswapv2oracle.json");

const account = "enter ethereum publickeyhere";
web3.eth.defaultAccount = account;

const privateKey = Buffer.from("Enter ethereum private key here", "hex");

const abi = uniswaporacleabi;

const address = "0x127a2975c4E1c75f1ed4757a861bbd42523DB035";
const oracle = new web3.eth.Contract(abi, address);

_getGasPrice();

function _getGasPrice() {
  axios
    .get("https://gasprice.poa.network/")
    .then((resp) => {
      oracle.methods
        .updateable()
        .call({ from: account }, function (error, result) {
          if (result) {
            update(resp.data.instant);
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

function update(gwei) {
  web3.eth.getTransactionCount(account, (err, txCount) => {
    // Build the transaction
    const txObject = {
      nonce: web3.utils.toHex(txCount),
      to: address,
      value: web3.utils.toHex(web3.utils.toWei("0", "ether")),
      gasLimit: web3.utils.toHex(1000000),
      gasPrice: web3.utils.toHex(web3.utils.toWei("" + gwei, "gwei")),
      data: oracle.methods.work().encodeABI(),
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
