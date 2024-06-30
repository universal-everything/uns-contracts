const { ethers } = require('hardhat');

async function main() {
  // RPC URL (the same one you used for deployment)
  const rpcUrl = 'https://rpc.testnet.lukso.network';

  // Contract address (replace with your contract's deployed address)
  const contractAddress = '0x648497a80c0499BEb5e18965Ba45c9A8B809EB4e';

  // Connect to the RPC endpoint
  const provider = new ethers.JsonRpcProvider(rpcUrl);

  // Get the signer (the same way as in your deployment script)
  const [deployer] = await ethers.getSigners();

  // Deploy MyContract
  const LYXRegistrar = await ethers.getContractFactory('LYXRegistrar');
  const myLYXRegistrar = await LYXRegistrar.connect(deployer).deploy(
    contractAddress,
    '0x94cfba061608af7c48de54c601c78a4e2682021535e4b15c0c0c681b65d5315d',
    'Testnet',
    'TLYX',
    deployer.address,
    deployer.address,
  );
  await myLYXRegistrar.waitForDeployment();
  console.log('Registar LUX deployed to:', myLYXRegistrar.target);

  // Deploy MyContract
  const FixPriceOracle = await ethers.getContractFactory('FixPriceOracle');
  const myOracle = await FixPriceOracle.connect(deployer).deploy();
  await myOracle.waitForDeployment();
  console.log('MyContract deployed to:', myOracle.target);

  // Deploy MyContract
  const LYXController = await ethers.getContractFactory('LYXFIFSController');
  const myLYXController = await LYXController.connect(deployer).deploy(
    myLYXRegistrar.target,
    '0xE4a54a910d755f45557b8177e547497161823D25',
    myOracle.target,
    60,
    1000,
  );

  await myLYXController.waitForDeployment();
  console.log('Controller deployed to:', myLYXController.target);

  await myLYXRegistrar.addController(myLYXController.target);
  await myLYXRegistrar.addController(deployer.address);

  // Get the contract ABI
  const MyContract = await ethers.getContractFactory('UNSRegistry');

  // Get the contract instance
  const myContract = new ethers.Contract(contractAddress, MyContract.interface, provider);

  // Prepare the arguments
  const parentNameHash = ethers.ZeroHash; // bytes32(0)
  const subNameLabelHash = ethers.keccak256(ethers.toUtf8Bytes('lyx'));

  // Specify the other arguments
  const ownerAddress = myLYXRegistrar.target;
  const resolverAddress = '0x40Ff65b86376A9912Ef5Ec7fecfAEbec5C2F2AB7';
  const ttl = 3600; // Replace with desired TTL in seconds

  //   Call the setSubNameRecord function
  const tx = await myContract
    .connect(deployer)
    .setSubNameRecord(parentNameHash, subNameLabelHash, ownerAddress, resolverAddress, ttl);

  // Wait for the transaction to be mined
  await tx.wait();

  console.log('SubNameRecord set successfully');

  // Get the contract ABI
  const reverseRegi = await ethers.getContractFactory('ReverseRegistrar');

  // Get the contract instance
  const reverseRegistrar = new ethers.Contract(
    '0xE4a54a910d755f45557b8177e547497161823D25',
    reverseRegi.interface,
    deployer,
  );

  await reverseRegistrar.addController(myLYXController.target);
  await reverseRegistrar.addController(deployer.address);
  await reverseRegistrar.setDefaultResolver('0x40Ff65b86376A9912Ef5Ec7fecfAEbec5C2F2AB7');

  // Deploy MyContract
  const StaticBulkRenewal = await ethers.getContractFactory('StaticBulkRenewal');
  const myBulkRenewal = await StaticBulkRenewal.connect(deployer).deploy(myLYXController.target);
  await myBulkRenewal.waitForDeployment();
  console.log('MyContract deployed to:', myBulkRenewal.target);

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
