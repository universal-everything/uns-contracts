const { ethers } = require('hardhat');

async function main() {
  // Connect to the RPC endpoint
  const provider = new ethers.JsonRpcProvider('https://rpc.testnet.lukso.network');

  // Get the signer (first signer from the provider)
  const [deployer] = await ethers.getSigners();

  // Deploy MyContract
  const MyContract = await ethers.getContractFactory('ReadOnlyResolver');
  const myContract = await MyContract.connect(deployer).deploy(
    '0x648497a80c0499BEb5e18965Ba45c9A8B809EB4e',
  );
  await myContract.waitForDeployment();
  console.log('MyContract deployed to:', myContract.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
