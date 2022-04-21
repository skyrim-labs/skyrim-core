const fs = require('fs');

const deployedContractsAddress = require('../constants/deployedContractsAddress');

module.exports = async function(callback) {
    try {
        const accounts = await web3.eth.getAccounts()

        owner = accounts[0];

        const path = __dirname + '/../build/contracts';
        const deployedContractsPath = __dirname + '/../constants/deployedContractsAddress.js';

        SkyrimTokenAddress = '0x835af8A0B662869c1D7A69717b20De3f7a53F588';

        STAndSkyrimPairAddress =  '0xfA096EE95Bc02552130F7647c3a12AaBFf4AAaFf';
        JTAndSkyrimPairAddress =  '0x9F40231eF8dff5003D24b5792bAcF086FaD9D701';
        SkyrimAndDAIPairAddress =  '0x47a0f19F345E3CD4C0F0148CD9273483283a65a3';


        STAndSkyrimRewardPollData = fs.readFileSync(`${path}/STAndSkyrimLPTokenStakeRewardPool.json`, 'utf8');
        STAndSkyrimRewardPollDataJson = JSON.parse(STAndSkyrimRewardPollData);
        STAndSkyrimRewardPollContract = new web3.eth.Contract(STAndSkyrimRewardPollDataJson.abi);

        await STAndSkyrimRewardPollContract.deploy({
            data: STAndSkyrimRewardPollDataJson.bytecode,
            arguments: [STAndSkyrimPairAddress, SkyrimTokenAddress]
        })
        .send({
            from: owner
        })
        .then(function(newContractInstance){
            STAndSkyrimRewardPollContract = newContractInstance;
            console.log("STAndSkyrimRewardPollContract = ", STAndSkyrimRewardPollContract.options.address) // instance with the new contract address
            deployedContractsAddress["STAndSkyrimRewardPoolAddress"] = STAndSkyrimRewardPollContract.options.address;
        });

        JTAndSkyrimRewardPollData = fs.readFileSync(`${path}/JTAndSkyrimLPTokenStakeRewardPool.json`, 'utf8');
        JTAndSkyrimRewardPollDataJson = JSON.parse(JTAndSkyrimRewardPollData);
        JTAndSkyrimRewardPollContract = new web3.eth.Contract(JTAndSkyrimRewardPollDataJson.abi);

        await JTAndSkyrimRewardPollContract.deploy({
            data: JTAndSkyrimRewardPollDataJson.bytecode,
            arguments: [JTAndSkyrimPairAddress, SkyrimTokenAddress]
        })
        .send({
            from: owner
        })
        .then(function(newContractInstance){
            JTAndSkyrimRewardPollContract = newContractInstance;
            console.log("JTAndSkyrimRewardPollContract = ", JTAndSkyrimRewardPollContract.options.address) // instance with the new contract address
            deployedContractsAddress["JTAndSkyrimRewardPoolAddress"] = JTAndSkyrimRewardPollContract.options.address;
        });

        SkyrimAndDAIRewardPollData = fs.readFileSync(`${path}/SkyrimAndDAILPTokenStakeRewardPool.json`, 'utf8');
        SkyrimAndDAIRewardPollDataJson = JSON.parse(SkyrimAndDAIRewardPollData);
        SkyrimAndDAIRewardPollContract = new web3.eth.Contract(SkyrimAndDAIRewardPollDataJson.abi);

        await SkyrimAndDAIRewardPollContract.deploy({
            data: SkyrimAndDAIRewardPollDataJson.bytecode,
            arguments: [SkyrimAndDAIPairAddress, SkyrimTokenAddress]
        })
        .send({
            from: owner
        })
        .then(function(newContractInstance){
            SkyrimAndDAIRewardPollContract = newContractInstance;
            console.log("SkyrimAndDAIRewardPollContract = ", SkyrimAndDAIRewardPollContract.options.address) // instance with the new contract address
            deployedContractsAddress["SkyrimAndDAIRewardPoolAddress"] = SkyrimAndDAIRewardPollContract.options.address;
        });

        fs.writeFileSync(deployedContractsPath, 'module.exports = ' + JSON.stringify(deployedContractsAddress));
    }
    catch(error) {
        console.log(error)
    }

    callback();
}