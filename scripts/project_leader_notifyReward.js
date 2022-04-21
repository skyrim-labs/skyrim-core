const fs = require('fs');

const STAndTRARewardPool = artifacts.require("STAndTRALPTokenStakeRewardPool");
const JTAndTRARewardPool = artifacts.require("JTAndTRALPTokenStakeRewardPool");
const TRAAndDAIRewardPool = artifacts.require("TRAAndDAILPTokenStakeRewardPool");

const deployedContractsAddress = require('../constants/deployedContractsAddress'); 

module.exports = async function(callback) {
    try {
        const accounts = await web3.eth.getAccounts()

        owner = accounts[0];

        const path = __dirname + '/../build/contracts';
        
        data = fs.readFileSync(`${path}/SkyrimToken.json`, 'utf8');
        dataJson = JSON.parse(data);
        TRATokenInstance = new web3.eth.Contract(dataJson.abi, deployedContractsAddress["TRAAddress"]);

        // ST And TRA
        // TRATokenInstance.methods.addMinter(deployedContractsAddress["STAndTRARewardPoolAddress"]).send({from: owner});
        // data = fs.readFileSync(`${path}/STAndTRALPTokenStakeRewardPool.json`, 'utf8');
        // dataJson = JSON.parse(data);
        // STrewardPoolContract = new web3.eth.Contract(dataJson.abi, deployedContractsAddress["STAndTRARewardPoolAddress"]);

        // result = await STrewardPoolContract.methods.setRewardDistributionManager(owner).send({from: owner});
        // console.log("1- result", result);

        // result = await STrewardPoolContract.methods.notifyRewardAmount("1000000000000000000000000").send({from: owner});
        // console.log("2- result", result);

        // JT And TRA
        TRATokenInstance.methods.addMinter(deployedContractsAddress["JTAndTRARewardPoolAddress"]).send({from: owner});

        data = fs.readFileSync(`${path}/JTAndTRALPTokenStakeRewardPool.json`, 'utf8');
        dataJson = JSON.parse(data);
        JTrewardPoolContract = new web3.eth.Contract(dataJson.abi, deployedContractsAddress["JTAndTRARewardPoolAddress"]);

        result = await JTrewardPoolContract.methods.setRewardDistributionManager(owner).send({from: owner});
        console.log("1- result", result);

        result = await JTrewardPoolContract.methods.notifyRewardAmount("1000000000000000000000000").send({from: owner});
        console.log("2- result", result);

        // TRA And DAI
        TRATokenInstance.methods.addMinter(deployedContractsAddress["TRAAndDAIRewardPoolAddress"]).send({from: owner});

        data = fs.readFileSync(`${path}/TRAAndDAILPTokenStakeRewardPool.json`, 'utf8');
        dataJson = JSON.parse(data);
        TRArewardPoolContract = new web3.eth.Contract(dataJson.abi, deployedContractsAddress["TRAAndDAIRewardPoolAddress"]);

        result = await TRArewardPoolContract.methods.setRewardDistributionManager(owner).send({from: owner});
        console.log("1- result", result);

        result = await TRArewardPoolContract.methods.notifyRewardAmount("1000000000000000000000000").send({from: owner});
        console.log("2- result", result);
    }
    catch(error) {
        console.log(error)
    }

    callback();
}