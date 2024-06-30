const { ethers } = require('hardhat');

async function main() {
  // Connect to the RPC endpoint
  const provider = new ethers.JsonRpcProvider('https://rpc.testnet.lukso.network');

  // Get the signer (first signer from the provider)
  const [deployer] = await ethers.getSigners();

  // Deploy MyContract
  const MyContract = await ethers.getContractFactory('UNSRegistry');
  const myContract = await MyContract.connect(deployer).deploy(deployer.address);
  await myContract.waitForDeployment();
  console.log('MyContract deployed to:', myContract.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
