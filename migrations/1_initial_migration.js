const Migrations = artifacts.require("Migrations");
const Strings    = artifacts.require("Strings");
const BIoTMgmt   = artifacts.require("BIoTMgmt");

module.exports = function (deployer) {
    deployer.deploy(Migrations);
    deployer.deploy(Strings);
    deployer.deploy(BIoTMgmt);
};

//eof
