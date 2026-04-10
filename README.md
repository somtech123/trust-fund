
# TrustVault Protocol — Decentralized Trust Fund Protocol

A descentralized protocol for securely locking and distributing funds based on a predefined condition
---



##  Table of Contents

- [Overview](#overview)
- [Deployed Contracts](#deployed)
- [Why TrustVault](#why-trustvault)
- [Architecture](#architecture)
- [Smart Contracts](#smart-contracts)
  - [VaultFactory](#vaultfactory)
    - [Constructor](#constructor)
    - [Functions](#functions)
      - [depositLink](#depositlink)
      - [createVault](#createvault)
    - [Events](#events)
    - [LINK Approval Flow](#link-approval-flow)
  - [Vault](#vault)
    - [Modifier](#modifier)
    - [Vault States](#vault-states)
    - [Functions](#functions-1)
      - [checkUpkeep](#checkupkeep)
      - [performUpkeep](#performupkeep)
      - [withdraw](#withdraw)
    - [Withdrawal Flow](#withdrawal-flow)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Dependencies](#dependencies)
- [Deployment](#deployment)
  - [Run Locally on Anvil](#run-locally-on-anvil)
  - [Run on Testnet Sepolia](#run-on-testnet-sepolia)
- [Chainlink Addresses — Sepolia](#chainlink-addresses--sepolia-testnet)
- [Security](#security)
  - [Audit Status](#audit-status)
  - [Known Considerations](#known-considerations)
- [Contributing](#contributing)
  - [Guidelines](#guidelines)
- [Issues](#issues)
- [License](#license)

---

## Overview

**TrustVault** is a smart contract protocol for creating secure on-chain trust funds where users can deposit assets, assign beneficiaries, and define conditions for withdrawals. each funds is deployed via a factory, ensuring scalability, isolation and temper-proof fund distribution with built in security features

### Why TrustVault?

| Features | Traditional Platforms | TrustVault |
|---|---|---|
| Control of funds | Managed by banks or intermediaries | Controlled by smart contracts
| Transparency | Limited, Opaque processes | Fully Transparent and on-chain
| Access | Requires approvals and paperwork | Permissionless and global access
| Execution of rules | Manually enforced | Automatically enforced by contract
| Speed | Slow(Manual processing) | Fast (automated execution)
| Custom conditions | Limited Flexibility | Fully customizable(time lock triger)

## Deployed Contracts — Sepolia Testnet

| Contract         | Address                                                                                                                         |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `VaultFactory`   | [`0x776EC3A61D2679B0207018BC19370Aaa2343a20A`](https://sepolia.etherscan.io/address/0x776EC3A61D2679B0207018BC19370Aaa2343a20A) |
| `Vault` | [`0x7f9ccbf7ecf9f7f0029142188dbd4e05613db97c`](https://sepolia.etherscan.io/address/0x7f9ccbf7ecf9f7f0029142188dbd4e05613db97c) |


## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        TrustVault Protocol                        │
│                                                                   │
│   ┌───────────────────┐              ┌───────────────────────┐    │
│   │   VaultFactory    │   deploys    │     TrustFundVault    │    │
│   │                   │─────────────▶│                       │    │
│   │  createVault()    │              │  checkUpkeep()         │   │
│   │  depositLinkToken() │            │  performUpkeep()       │   │
│   │  registerUpkeep() │              │  withdraw()            │   │
│   └───────────────────┘              └───────────────────────┘    │
│            │                                    │                 │
│            │ funds LINK                         │ unlocked = true │
│            │ for upkeep                         │ (time elapsed)  │
│            │                                    │                 │
│            ▼                                    ▼                 │
│   ┌──────────────────────────────────────────────────────────┐    │
│   │                  Chainlink Automation                     │   │
│   │                                                           │   │
│   │   Registry ──▶ Keeper Node ──▶ checkUpkeep() ──▶         │   │
│   │                               performUpkeep()            │    │
│   │        (stores upkeepId)      (polls off-chain)          │    │
│   └──────────────────────────────────────────────────────────┘    │
│                                                                   │
│   Flow:  deploy ──▶ deposit LINK ──▶ create vault + deposit ETH  │
│          ──▶ time elapses ──▶ Chainlink unlocks vault            │
│          ──▶ beneficiary calls withdraw() ──▶ ETH released       │
└──────────────────────────────────────────────────────────────────┘
```

---
## Smart Contracts


### VaultFactory

The `VaultFactory` is the entry point of the protocol. It deploys new `Vault` instances, funds Chainlink upkeep with LINK, and registers each vault with the Chainlink Automation Registry so time-based unlocking works automatically.

---

### Constructor

```solidity
constructor(
    address _linkToken,
    address _registerAddress
)
```

| Parameter          | Type      | Description                                   |
| ------------------ | --------- | --------------------------------------------- |
| `_linkToken`       | `address` | Address of the LINK token contract            |
| `_registerAddress` | `address` | Address of the Chainlink Automation Registrar |

---

### Functions
### depositLink

```solidity
function depositLink(uint96 _amount) external
```

Transfers LINK from the caller into the factory to fund vault upkeep registrations. Must be called before or alongside `createVault` if the factory does not already hold enough LINK.

**Approval required** — before calling `depositLink`, the caller must approve the factory contract to spend LINK on their behalf. Without this the transaction will revert.

```solidity
// Step 1 — approve the factory to pull LINK from your wallet
IERC20(linkToken).approve(address(factory), _amount);

// Step 2 — deposit LINK into the factory
factory.depositLink(_amount);
```

The approval amount must be **greater than or equal to** `_amount`. You can check your current allowance with:

```solidity
IERC20(linkToken).allowance(msg.sender, address(factory));
```

**Etherscan Approval** - alternatively caller can approve link in etherscan

#### Approve LINK Via Etherscan

```
1.	Open the LINK token contract on Etherscan
2.	Click “Connect to Web3” and connect your wallet (e.g. MetaMask)
3.	Go to Contract → Write Contract
4.	Call approve(spender, amount)
    → spender: your contract address
    → amount: LINK amount in wei (1 LINK = 1e18)
5.	Confirm the transaction
```

---
### CreateVault
---

```solidity
function createVault(
    uint256 amountInWei,
    uint96 linkAmountInWei,
    uint256 releaseTime,
    address[] calldata beneficiaries
) external payable returns (address vaultAddress, uint256 upkeepID)
```

Deploys a new `Vault`, registers it with Chainlink Automation, and stores it against the caller. The ETH sent with the call is forwarded into the vault as the trust deposit.

---

| Parameter         | Type                 | Description                                                                               |
| ----------------- | -------------------- | ----------------------------------------------------------------------------------------- |
| `amountInWei`     | `uint256`            | Amount of ETH in wei to lock inside the vault. Must match `msg.value`                     |
| `linkAmountInWei` | `uint96`             | Amount of LINK in wei to fund the Chainlink upkeep. Caller must approve factory first     |
| `releaseTime`     | `uint256`            | Lock duration in whole days. Converted to seconds internally — e.g. `7` = 7 days from now |
| `beneficiaries`   | `address[] calldata` | Ordered list of unique addresses allowed to withdraw after `releaseTime` has elapsed      |

---

---

#### Events

```solidity
event CreatedVault(
    address indexed creator,
    uint256 amount,
    uint256 counter,
    uint256 upKeepId
)
```

Emitted when a new vault is successfully deployed and registered with Chainlink.

---

### LINK Approval Flow

Before interacting with the factory, the caller must approve LINK spending in the correct order:

```
1. Caller approves factory         LINK.approve(factory, amount)
         │
         ▼
2. Caller calls depositLink(.)      factory.depositLink(amount)
         │
         ▼
3. Factory pulls LINK              LINK.transferFrom(caller, factory, amount)
         │
         ▼
4. Caller calls createVault(...)   Creates new vault contracts and registry.registerUpkeep(vault, amount)
         │
         ▼
5. Chainlink holds LINK            upkeep is live and funded
```

---

---

## Vault

A time-locked vault deployed exclusively by `VaultFactory`. Once the release time elapses, Chainlink Automation triggers `performUpkeep()` which splits the locked funds equally among all beneficiaries and stages them into a pending withdrawal mapping. Each beneficiary then claims their share independently by calling `withdraw()`.

---

#### Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                             TrustFundVault                               │
│                                                                          │
│  State: OPEN ──▶ CLOSED                                                  │
│                                                                          │
│  ┌──────────────────────┐          ┌─────────────────────────────────┐  │
│  │      Vault State     │          │      Chainlink Automation        │  │
│  │                      │          │                                  │  │
│  │  lockedFunds         │          │  checkUpkeep()                   │  │
│  │  beneficiaries[]     │─────────▶│  · block.timestamp >= release?   │  │
│  │  releaseTime         │          │  · factory.isValidVault(this)?   │  │
│  │  factoryAddress      │          │  · state == OPEN?                │  │
│  │  creatorAddress      │          │                                  │  │
│  └──────────────────────┘          │  all true ──▶ upkeepNeeded       │  │
│                                    │                    │             │  │
│                                    │                    ▼             │  │
│                                    │  performUpkeep()                 │  │
│                                    │  · share = balance / n           │  │
│                                    │  · remainder ──▶ last            │  │
│                                    │    beneficiary                   │  │
│                                    │  · pendingWithdrawals[each]      │  │
│                                    │    += share                      │  │
│                                    │  · state = CLOSED                │  │
│                                    │  · emit Vault__UpKeepPerformed   │  │
│                                    └──────────────────┬───────────────┘  │
│                                                       │                  │
│                                                       ▼                  │
│                          ┌────────────────────────────────────────┐      │
│                          │          withdraw()                     │      │
│                          │                                         │      │
│                          │  · require pendingWithdrawals[msg       │      │
│                          │    .sender] > 0                         │      │
│                          │  · clear mapping entry                  │      │
│                          │  · transfer ETH to beneficiary          │      │
│                          │  · emit Vault__Withdrawn                │      │
│                          └────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### Modifier

```solidity
modifier onlyValidVault()
```

Reverts if the vault was not deployed by the `VaultFactory`. Every state-changing function is gated by this modifier to ensure no rogue or manually deployed vault can interact with the protocol.

```solidity
// Internally checks
if (!VaultFactory(FACTORY_ADDRESS).isValidVault(address(this)))
            revert Vault__InValidVault();
```

---

### Vault States

| State   | Description                                                             |
| ------- | ----------------------------------------------------------------------- |
| `OPEN`  | Funds are locked. Release time has not elapsed yet                      |
| `CLOSE` | Chainlink has triggered `performUpkeep()`. Funds are pending withdrawal |

---

### Functions

#### checkUpkeep

```solidity
function checkUpkeep(
    bytes calldata
) external view returns (bool upkeepNeeded, bytes memory)
```

Called off-chain by the Chainlink Keeper node on every block. Returns `upkeepNeeded = true` only when **all three** conditions are met:

| Condition           | Check                                 |
| ------------------- | ------------------------------------- |
| Time elapsed        | `block.timestamp >= releaseTime`      |
| Vault is valid      | `factory.isValidVault(address(this))` |
| Vault state is OPEN | `state == VaultState.OPEN`            |

---

#### performUpkeep

```solidity
function performUpkeep(
    bytes calldata
) external onlyValidVault
```

Called on-chain by the Chainlink Keeper once `checkUpkeep` returns true. Splits the locked balance equally among all beneficiaries and stages the amounts into `pendingWithdrawals`. Any indivisible remainder goes to the last beneficiary in the list.

**Distribution logic:**

```
share     = totalBalance / beneficiaries.length
remainder = totalBalance % beneficiaries.length

each beneficiary        ──▶ pendingWithdrawals[address] += share
last beneficiary only   ──▶ pendingWithdrawals[address] += remainder
```

Vault state is updated to `CLOSE` and `FundsReleased` is emitted.

---

#### withdraw

```solidity
function withdraw() external nonReentrant onlyValidVault
```

Called by a beneficiary after `performUpkeep` has run. Reverts if the caller has no pending withdrawal amount. Clears the mapping entry before transferring to prevent reentrancy also uses openzeppelin ReentrancyGuard to prevent reentry.

**Only addresses in `pendingWithdrawals` with a balance greater than zero can call this function.** Calling it before `performUpkeep` or from a non-beneficiary address will revert.

---

## Withdrawal Flow

```
Chainlink detects time elapsed
         │
         ▼
checkUpkeep() ──▶ upkeepNeeded = true
         │
         ▼
performUpkeep()
  · split totalBalance / beneficiaries.length
  · remainder ──▶ last beneficiary
  · pendingWithdrawals[each] = share
  · state = RELEASED
  · emit FundsReleased()
         │
         ├──▶ beneficiary[0].withdraw() ──▶ ETH transferred ──▶ mapping cleared
         ├──▶ beneficiary[1].withdraw() ──▶ ETH transferred ──▶ mapping cleared
         └──▶ beneficiary[n].withdraw() ──▶ ETH transferred ──▶ mapping cleared
                                                                        │
                                                                        ▼
                                                               state = CLOSED
```

---

## Security Notes

- `performUpkeep` can only be called by the Chainlink Automation Registry — any direct call from an EOA or non-keeper address will revert via `onlyValidVault`
- `withdraw()` clears `pendingWithdrawals[msg.sender]` before transferring ETH to prevent reentrancy attacks
- The vault can only be deployed by `VaultFactory` — the `onlyValidVault` modifier enforces this on every function
- Beneficiary addresses are validated for uniqueness at vault creation inside the factory



##  Getting Started

### Prerequisites

Ensure you have the following installed before continuing:

| Tool       | Version    | Install                                              |
| ---------- | ---------- | ---------------------------------------------------- |
| Git        | latest     | [git-scm.com](https://git-scm.com)                  |
| Foundry    | latest     | [getfoundry.sh](https://getfoundry.sh)               |
| Node.js    | >= 18.x    | [nodejs.org](https://nodejs.org)                     |

---

## Installation

```bash
# Clone the repository
git clone https://github.com/somtech123/TrustVault
cd trustvault-protocol

# Install Foundry dependencies
forge install

# add environment file
touch .env
```

Open `.env` and fill in the required values:

```bash
PRIVATE_KEY=           # your wallet private key
SEPOLIA_RPC_URL=       # your Sepolia RPC URL (Alchemy or Infura)
ETHERSCAN_API_KEY=     # for contract verification
LOCAL_RPC_URL          # anvil Sepolia RPC URL http://127.0.0.1:8545
LOCAL_PRIVATE_KEY      # anvil wallet private key
LINK_TOKEN_ADDRESS=    # LINK token address on sepolia network
AUTOMATION_REGISTRY=   # Chainlink Automation Registrar address on sepolia network
```

## Dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts
forge install smartcontractkit/chainlink
forge install foundry-rs/forge-std
```

##  Deployment


## Run Locally on Anvil

Anvil spins up a local blockchain with funded test accounts. No real ETH or LINK needed uses mock LINK to register upkeep.

**1. Start Anvil in a separate terminal**

```bash
anvil
```

**2. Deploy the contracts**

```bash
forge script script/DeployVault.s.sol \
  --rpc-url $LOCAL_RPC_URL \
  --private-key $LOCAL_PRIVATE_KEY \
  --broadcast
```

**Interact with cast send**

## Run on Testnet (Sepolia)

> **You will need Sepolia ETH and Sepolia LINK.**
>
> - Sepolia ETH — [sepoliafaucet.com](https://sepoliafaucet.com)
> - Sepolia LINK — [faucets.chain.link](https://faucets.chain.link)

**1. Load your `.env`**

```bash
source .env
```

**2. Deploy the factory**

```bash
forge script script/DeployVault.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**3. Approve LINK spending**

Before creating a vault the factory must be approved to pull LINK from your wallet:

```bash
cast send $LINK_TOKEN_ADDRESS \
  "approve(address,uint256)" \
    \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**4. Deposit LINK into the factory**

```bash
cast send  \
  "depositLinkToken(uint96)"  \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**5. Create a vault**

```bash
cast send  \
  "createVault(address,uin696,uint256,address[])" \
    \
  --value  \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**6. Monitor upkeep on Chainlink**

Once the vault is created and registered, Chainlink Automation will monitor it automatically. Track your upkeep at:

```
https://automation.chain.link/sepolia/<UPKEEP_ID>
```

**7. Withdraw after unlock**

Once Chainlink calls `performUpkeep` and the vault state changes to `CLOSED`, each beneficiary can withdraw their share:

```bash
cast send  \
  "withdraw()" \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key
```


##  Usage Guide
## Chainlink Addresses — Sepolia Testnet

The following addresses are required in your `HelperConfig` before deploying to Sepolia.

---

### Contracts

| Contract                    | Address                                      | Description                                              |
| --------------------------- | -------------------------------------------- | -------------------------------------------------------- |
| LINK Token                  | `0x779877A7B0D9E8603169DdbD7836e478b4624789` | ERC-677 LINK token on Sepolia                            |
| Automation Registrar (v2.1) | `0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976` | Registers new upkeeps — passed to `VaultFactory`         |
| Automation Registry (v2.1)  | `0x86EFBD0b6736Bed994962f9797049422A3A8E8Ad` | Tracks all active upkeeps and keeper nodes               |

> Always verify these addresses against the official Chainlink docs before deploying:
> [docs.chain.link/chainlink-automation/overview/supported-networks](https://docs.chain.link/chainlink-automation/overview/supported-networks)

---
## Security

### Audit Status

This protocol has not been formally audited. It is currently in active development and
deployed on Sepolia testnet only. **Do not use this contract to manage real funds until
a full audit has been completed.**

---

### Known Considerations

| Area                     | Detail                                                                                          |
| ------------------------ | ----------------------------------------------------------------------------------------------- |
| Reentrancy               | `withdraw()` clears `pendingWithdrawals[msg.sender]` before transferring ETH                   |
| Factory validation       | `onlyValidVault` modifier prevents rogue vaults from interacting with the protocol             |
| Chainlink dependency     | `performUpkeep` relies on Chainlink Automation — ensure upkeep is sufficiently funded in LINK  |
| LINK approval            | Caller must approve the factory before `depositLink()` — never approve more than needed        |
| Beneficiary ordering     | The last beneficiary in the array receives the indivisible remainder — verify ordering at deploy|
| Underfunded upkeep       | If LINK balance drops to zero the vault will never unlock — monitor upkeep balance regularly   |

---

## Contributing

Contributions are welcome.
```
To contribute:
1.	Fork the repository
2.	Create a new branch git checkout -b feature/your-feature-name
3.	Make your changes
4.	Add or update tests (forge test)
5.	Commit your changes git commit -m "feat: short description"
6.	Push to your branch git push origin feature/your-feature-name
7.	Open a Pull Request

```


## Guidelines
- Match the existing code style — run `forge fmt` before committing
- Write clear commit messages that describe *what* changed and *why*
- All tests must pass before opening a PR — run `forge test`
- New features and bug fixes must include test coverage — run `forge coverage`
- Keep pull requests focused — one concern per PR, no unrelated changes bundled in

---

## Issues
For bugs or feature requests, open an issue with a clear description and steps to reproduce.

## Security

If you discover a vulnerability please **do not open a public issue**. Instead, report
it privately by texting me on x :

```
@it_dre_dr
```

##  License

MIT License — see [LICENSE](https://choosealicense.com/licenses/mit/) for details.

---
