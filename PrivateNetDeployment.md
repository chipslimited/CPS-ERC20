# Private Net 47.88.61.217
Private net is a private testnet of Ethereum which is isolated from Ethereum mainnet and testnet.

CPS is deployed at private net 47.88.61.217 on Mar 07 2018 as follows

* Contract Address: 0x0E3E4BfD5a2572c1E0475029D43Ac0D274466017 
* Name: CPSTestToken
* Symbol: CPSTest
* Decimals: 8
* Total supply: 1000000000.00000000 CPSTest

Total supply is distributed to the following addresses
 
 * A 0x024451e7916d1d0281A608B04939586a7F2fD37F 300000000.00000000  fund not available until operation team manually unlocks
 * B 0x1DCf871ecaAa5Ba9241E565267c2DFE9e331d6C6 150000000.00000000  fund not available in 3 years (locked 94608000s) operation team cannot unlock in 3 years
 * C1 0x3Ad8E463063606C5B0C1D5E4741f09018e3e697F 12500000.00000000  fund not available in 3 months (locked 7948800 s) operation team cannot unlock in 3 months
 * C2 0xDa34fA66a3B7c1eB870253ee5dA0DaCC079db2e1 12500000.00000000  fund not available in 6 months (locked 15811200 s) operation team cannot unlock in 6 months
 * C3 0xFA812Fb2A9f590f730Fe1685fE483e5adbE5DE66 12500000.00000000  fund not available in 9 months (locked 23673600 s) operation team cannot unlock in 9 months
 * C4 0xd702101b69D3B41273296f0331E17D6D2e1769c3 12500000.00000000  fund not available in 12 months (locked 31622400 s) operation team cannot unlock in 12 month
 * D 0x757b5F0B13fbBA442f91Cb8da0dA3cE9d6631BBf: 50000000.00000000
 * E 0xB0Eb1166595e9e88a2F8855C5bC52399aaa6Be78: 150000000.00000000
 * F 0x04D8744a6AC00D995D0F06d8ECd9CE2755bc6D2D: 240000000.00000000
 * G 0x15972d172a14D78996a1C754A8C82841C37DE435:  60000000.00000000 
 
 # Deployment
 Deployment is done using Mist, a official Ethereum Wallet/Development tool.
 Mist can be download from 
 * Windows version 
 https://github.com/ethereum/mist/releases/download/v0.9.3/Mist-installer-0-9-3.exe
 * macos version 
 https://github.com/ethereum/mist/releases/download/v0.9.3/Mist-macosx-0-9-3.dmg
 ![Contract Deployment in Mist](https://raw.githubusercontent.com/chipslimited/CPS-ERC20/master/deployment.png)
 
 # Fund distribution
 In order to distribute fund to various address after contract creation, we use the transfer multiple function of the smart contract.

  ![Call Transfer Multiple in Mist](https://raw.githubusercontent.com/chipslimited/CPS-ERC20/master/transfer_multiple.png)
 