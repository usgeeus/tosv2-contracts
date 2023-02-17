const { ethers, run } = require("hardhat");
const save = require("../save_deployed");
const loadDeployed = require("../load_deployed");
const { printGasUsedOfUnits } = require("../log_tx");

async function main() {
    const accounts = await ethers.getSigners();
    const deployer = accounts[0];
    console.log("deployer: ", deployer.address);

    const { chainId } = await ethers.provider.getNetwork();
    let networkName = "local";
    if(chainId == 1) networkName = "mainnet";
    if(chainId == 4) networkName = "rinkeby";
    if(chainId == 5) networkName = "goerli";

    let deployInfo = {
        name: "",
        address: ""
    }

    let uniswapPoolFactory = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
    let oracleLibrary , bonusRateLockUp, bondDepositoryV1_5

    // OracleLibrary Deploy
    let factory = await ethers.getContractFactory("OracleLibrary")
    oracleLibrary = await factory.deploy();
    await oracleLibrary.deployed()

    console.log("OracleLibrary: ", oracleLibrary.address);

    deployInfo = {
        name: "OracleLibrary",
        address: oracleLibrary.address
    }

    save(networkName, deployInfo);

    // BonusRateLockUp Deploy
    factory = await ethers.getContractFactory("BonusRateLockUp")
    bonusRateLockUp = await factory.deploy();
    await bonusRateLockUp.deployed()

    console.log("BonusRateLockUp: ", bonusRateLockUp.address);

    deployInfo = {
        name: "BonusRateLockUp",
        address: bonusRateLockUp.address
    }

    save(networkName, deployInfo);

    //BondDepositoryV1_5 Deploy
    factory = await ethers.getContractFactory("BondDepositoryV1_5")
    bondDepositoryV1_5 = await factory.deploy();
    await bondDepositoryV1_5.deployed()

    console.log("BondDepositoryV1_5: ", bondDepositoryV1_5.address);

    deployInfo = {
        name: "BondDepositoryV1_5",
        address: bondDepositoryV1_5.address
    }

    save(networkName, deployInfo);

    //bondDepositoryProxy

    let bondDepositoryProxyAbi = require('../../artifacts/contracts/BondDepositoryProxy.sol/BondDepositoryProxy.json');
    let bondDepositoryAbi = require('../../artifacts/contracts/BondDepositoryV1_5.sol/BondDepositoryV1_5.json');

    const bondDepositoryProxyAddress = loadDeployed(networkName, "BondDepositoryProxy");

    const bondDepositoryProxyContract = new ethers.Contract(bondDepositoryProxyAddress, bondDepositoryProxyAbi.abi, ethers.provider);
    await bondDepositoryProxyContract.connect(deployer).upgradeTo(bondDepositoryV1_5.address);

    console.log("bondDepositoryProxy: upgradeTo ", bondDepositoryV1_5.address);

    const bondDepositoryContract = new ethers.Contract(bondDepositoryProxyAddress, bondDepositoryAbi.abi, ethers.provider);
    let tx = await bondDepositoryContract.connect(deployer).changeOracleLibrary(
      oracleLibrary.address,
      uniswapPoolFactory
    );
    await tx.wait();
    console.log("bondDepository: changeOracleLibrary ", tx.hash);

    if(chainId == 1 || chainId == 4 || chainId == 5) {

      await run("verify", {
        address: oracleLibrary.address,
        constructorArgsParams: [],
      });

      await run("verify", {
        address: bonusRateLockUp.address,
        constructorArgsParams: [],
      });


      await run("verify", {
        address: bondDepositoryV1_5.address,
        constructorArgsParams: [],
      });
    }

    console.log("phase1.5 contracts verified");

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });