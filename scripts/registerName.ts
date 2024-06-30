const { ethers } = require('hardhat');

async function main() {
  // RPC URL (the same one you used for deployment)
  const rpcUrl = 'https://rpc.testnet.lukso.network';

  // Contract address (replace with your contract's deployed address)
  const contractAddress = '0x5587d2909565df38d633Cc4ef706c6A53846a580';

  // Connect to the RPC endpoint
  const provider = new ethers.JsonRpcProvider(rpcUrl);

  // Get the signer (the same way as in your deployment script)
  const [deployer] = await ethers.getSigners();

  // Get the contract ABI
  const MyContract = await ethers.getContractFactory('UNSRegistry');

  // Get the contract instance
  const myContract = new ethers.Contract(contractAddress, MyContract.interface, provider);

  // Prepare the arguments
  const parentNameHash = ethers.ZeroHash; // bytes32(0)
  const subNameLabelHash = ethers.keccak256(ethers.toUtf8Bytes('yamen'));

  // Specify the other arguments
  const ownerAddress = deployer.address;
  const resolverAddress = deployer.address;
  const ttl = 3600; // Replace with desired TTL in seconds

  //   Call the setSubNameRecord function
  const tx = await myContract
    .connect(deployer)
    .setSubNameRecord(parentNameHash, subNameLabelHash, ownerAddress, resolverAddress, ttl);

  // Wait for the transaction to be mined
  await tx.wait();

  console.log('SubNameRecord set successfully');

  // Now you can interact with the contract
  // For example, call a function of your contract
  // const result = await myContract.yourFunctionName(arg1, arg2, ...);

  // Example: Assuming 'yourFunctionName' is a function in your contract
  // console.log(`Function call result: ${result}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
