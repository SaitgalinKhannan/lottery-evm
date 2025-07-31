# SingleLottery Smart Contract

![Solidity](https://img.shields.io/badge/Solidity-%23363636.svg?style=for-the-badge&logo=solidity&logoColor=white)
![Ethereum](https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=Ethereum&logoColor=white)
![Foundry](https://img.shields.io/badge/Foundry-000000?style=for-the-badge&logo=ethereum&logoColor=white)

A decentralized lottery smart contract built with Solidity and Foundry. This contract implements a transparent, fair lottery system with configurable prize distribution and secure reward claiming mechanisms.

## 🎯 Features

### Core Functionality
- **Fair Lottery System**: Transparent lottery draws using blockchain-based randomness
- **Flexible Prize Distribution**: Configurable percentages for owner fees, winner prizes, and participant returns
- **Multiple Ticket Purchase**: Users can buy multiple tickets in a single transaction
- **Secure Reward Claims**: Protected reward claiming with reentrancy guards
- **Emergency Refunds**: Owner can initiate emergency refunds if needed
- **Ownership Transfer**: Contract ownership can be transferred to new addresses

### Security Features
- **Reentrancy Protection**: Prevents reentrancy attacks in reward claiming
- **Input Validation**: Comprehensive validation of all user inputs
- **Access Control**: Owner-only functions for critical operations
- **Safe Math**: Built-in protection against integer overflow/underflow
- **Transparent Randomness**: Uses blockchain-based randomness with external seed

## 🏗️ Project Structure

```
├── src/
│   └── SingleLottery.sol          # Main lottery contract
├── script/
│   └── SingleLottery.s.sol        # Deployment script
├── test/
│   └── SingleLottery.t.sol        # Comprehensive test suite
├── lib/
│   └── forge-std/                 # Foundry standard library
├── foundry.toml                   # Foundry configuration
└── .gitmodules                    # Git submodules configuration
```

## 🚀 Quick Start

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Node.js and npm/yarn (optional, for additional tooling)

### Installation

1. **Clone the repository**
```bash
git clone <your-repo-url>
cd <your-repo-name>
```

2. **Install dependencies**
```bash
forge install
```

3. **Build the contracts**
```bash
forge build
```

4. **Run tests**
```bash
forge test
```

### Deployment

1. **Set up environment variables**
```bash
# Create .env file
echo "PRIVATE_KEY=your_private_key_here" > .env
```

2. **Deploy to testnet (e.g., BSC Testnet)**
```bash
forge script script/SingleLottery.s.sol --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 --broadcast --verify
```

3. **Deploy to mainnet**
```bash
forge script script/SingleLottery.s.sol --rpc-url <mainnet-rpc-url> --broadcast --verify
```

## 📋 Contract Parameters

### Constructor Parameters
- `_ticketPrice`: Price per ticket in wei (e.g., 0.01 ether)
- `_maxTickets`: Maximum number of tickets available
- `_ownerFeePercent`: Percentage fee for contract owner (0-100)
- `_winnerPrizePercent`: Percentage prize for winner (0-100)
- `_returnedPrizePercent`: Percentage returned to all participants (0-100)

**Important**: The three percentage parameters must sum to exactly 100%.

### Example Configuration
```solidity
// 0.01 ETH per ticket, 100 tickets max
// 20% owner fee, 30% winner prize, 50% returned to participants
SingleLottery lottery = new SingleLottery(
    0.01 ether,  // ticketPrice
    100,         // maxTickets
    20,          // ownerFeePercent
    30,          // winnerPrizePercent
    50           // returnedPrizePercent
);
```

## 🎮 Usage

### For Participants

#### Buy Tickets
```solidity
// Buy 3 tickets
lottery.buyTickets{value: 0.03 ether}(3);
```

#### Check Your Information
```solidity
(uint256 tickets, uint256 rewards) = lottery.getMyInfo();
```

#### Claim Rewards
```solidity
lottery.claimReward();
```

### For Owner

#### Conduct Lottery Draw
```solidity
// Use external randomness source for fairness
uint256 randomSeed = 12345; // Get from external source
lottery.drawLottery(randomSeed);
```

#### Emergency Refund
```solidity
lottery.emergencyRefund();
```

#### Transfer Ownership
```solidity
lottery.transferOwnership(newOwnerAddress);
```

### View Functions

#### Get Contract Information
```solidity
uint256 balance = lottery.getContractBalance();
uint256 remaining = lottery.getRemainingTickets();
bool finished = lottery.lotteryFinished();
address winner = lottery.winner();
```

## 🧪 Testing

The project includes comprehensive tests covering all functionality:

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run specific test
forge test --match-test testBuyTickets

# Generate coverage report
forge coverage
```

### Test Coverage
- ✅ Ticket purchasing scenarios
- ✅ Lottery drawing mechanics
- ✅ Reward claiming and distribution
- ✅ Emergency refund functionality
- ✅ Access control and ownership
- ✅ Edge cases and error conditions
- ✅ Reentrancy protection
- ✅ Mathematical calculations

## 🔧 Configuration

### Foundry Configuration (`foundry.toml`)
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
```

### Supported Networks
The contract can be deployed on any EVM-compatible network:
- Ethereum Mainnet/Testnets
- BNB Smart Chain
- Polygon
- Avalanche
- And others...

## 🛡️ Security Considerations

### Implemented Protections
- **Reentrancy Guards**: Prevents reentrancy attacks in `claimReward()`
- **Input Validation**: All user inputs are validated
- **Access Control**: Critical functions are owner-only
- **Integer Safety**: Uses Solidity 0.8+ built-in overflow protection
- **State Management**: Proper state transitions and checks

### Randomness
The contract uses a combination of:
- `block.timestamp`
- `block.prevrandao` (replaces `block.difficulty` in post-merge Ethereum)
- Ticket owners array
- External random seed (provided by owner)

**Note**: For production use, consider using Chainlink VRF or similar oracle services for truly random number generation.

## 📊 Gas Optimization

The contract is optimized for gas efficiency:
- Uses `immutable` variables for deployment-time constants
- Efficient data structures and mappings
- Batch operations where possible
- Minimal storage operations

## 🔄 Lottery Lifecycle

1. **Deployment**: Owner deploys contract with parameters
2. **Ticket Sales**: Users buy tickets until sold out or manually drawn
3. **Drawing**: Owner calls `drawLottery()` with random seed
4. **Reward Distribution**: Participants claim their rewards
5. **Completion**: All funds distributed, lottery finished

## 🚨 Emergency Procedures

If issues arise, the owner can:
- Call `emergencyRefund()` to refund all participants
- Transfer ownership to a new address
- Monitor contract state through view functions

## 📝 Events

The contract emits the following events for transparency:
- `TicketPurchased(address buyer, uint256 amount)`
- `LotteryDrawn(address winner, uint256 winnerPrize)`
- `OwnershipTransferred(address indexed previousOwner, address indexed newOwner)`
- `RewardClaimed(address claimer, uint256 amount)`

## 🔗 Integration

To integrate with your frontend or backend:

1. **ABI Generation**
```bash
forge build
# ABI will be in out/SingleLottery.sol/SingleLottery.json
```

2. **Contract Interaction** (using ethers.js)
```javascript
const contract = new ethers.Contract(contractAddress, abi, signer);
await contract.buyTickets(3, { value: ethers.utils.parseEther("0.03") });
```

## 📄 License

This project is licensed under the MIT License - see the contract SPDX identifier for details.

## 🔗 Resources

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)
- [Ethereum Development](https://ethereum.org/developers/)