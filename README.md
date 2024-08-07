# AirdropMerkleNFTMarket

AirdropMerkleNFTMarket 是一个结合了 ERC20 代币预付、Merkle 树验证和 NFT 领取功能的智能合约系统。它还支持批量操作的 multicall 功能。

## 功能特性

- ERC20 代币预付功能
- 基于 Merkle 树的白名单验证
- NFT 铸造和分发
- 支持 multicall 的批量操作

## 合约结构

- `AirdropMerkleNFTMarket.sol`: 主合约，包含预付、验证和 NFT 领取逻辑
- `MultiDelegatecall.sol`: 支持批量调用的合约
- `ERC20Token.sol`: 用于预付的 ERC20 代币合约
- `ERC721Token.sol`: NFT 合约