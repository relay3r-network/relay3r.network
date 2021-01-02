var Web3 = require("web3");

const TokenMigrator = artifacts.require("TokenMigratorCustomizable");
//Mock testing token contract
const BurnableToken = artifacts.require("BurnableToken");

//Global vars
//Tokens
var Token1,Token2;
//Migrator
var TokenMigratorD;

contract("TokenMigratorCustomizable", async function () {
    it("Should Migrate tokens to V2", async () => {

    ///Deploy test tokens
     Token1 = await BurnableToken.new("TestToken1", "TXS");
     Token2 = await BurnableToken.new("TestToken2", "TXSS");
    //Deploy TokenMigrator
    TokenMigratorD = await TokenMigrator.new(Token1.address, Token2.address);
    assert(TokenMigratorD.address !== '');

    //Now transfer 1k tokens of token2 to migrator
    await Token2.transfer(
      TokenMigratorD.address,
      Web3.utils.toWei("1000", "ether")
    );
    //Approve 1k tokens to migrator contract
    await Token1.approve(
      TokenMigratorD.address,
      Web3.utils.toWei("1000", "ether")
    );
    //Swap 1k tokens to token2
    await TokenMigratorD.swapTokens(Web3.utils.toWei("1000", "ether"));

    const Token1SupplyAfterMigrate = await Token1.totalSupply();
    const Token2SupplyAfterMigrate = await Token2.totalSupply();

    //Check if migration was successful
    assert(Token1SupplyAfterMigrate == 0); //Supply of token 1 to be 0 after migration
    //supply of token 2 to be 1k after migration
    assert(Token2SupplyAfterMigrate == Web3.utils.toWei("1000", "ether"));
    });
});
