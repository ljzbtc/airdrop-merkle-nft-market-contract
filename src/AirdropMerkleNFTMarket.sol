// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MultiDelegatecall.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface MYNFT {
    function mint(address to, uint256 tokenId) external;
}

contract AirdropMerkleNFTMarket is MultiDelegatecall, Ownable {
    address public immutable TokenAddress;
    address public immutable NftAddress;
    uint256 public tokenId;

    bytes32 public merkleRoot;
    mapping(address => bool) public hasClaimed;
    IERC20 public immutable token;

    uint256 public constant PRE_PAY_AMOUNT = 0.1 ether; // 预付金额
    mapping(address => bool) public hasPrePaid;

    event PrePaid(address indexed user);
    event NftClaimed(address indexed user, uint256 tokenId);

    constructor(
        address _tokenAddress,
        address _nftAddress,
        bytes32 _merkleRoot
    ) Ownable(msg.sender) {
        TokenAddress = _tokenAddress;
        NftAddress = _nftAddress;
        merkleRoot = _merkleRoot;
        token = IERC20(_tokenAddress);
    }

    function permitPrePay(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(!hasPrePaid[msg.sender], "Already pre-paid");
        require(amount == PRE_PAY_AMOUNT, "Incorrect payment amount");

        IERC20Permit tokenper = IERC20Permit(TokenAddress);

        // 调用 token 的 permit 函数
        tokenper.permit(msg.sender, address(this), amount, deadline, v, r, s);

        // 转移代币到合约
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        hasPrePaid[msg.sender] = true;
        emit PrePaid(msg.sender);
    }

    function claimNftWithProof(bytes32[] calldata _merkleProof) public {
        require(hasPrePaid[msg.sender], "Must pre-pay first");
        require(!hasClaimed[msg.sender], "Already claimed");

        // 验证 Merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Invalid proof"
        );

        // 标记为已领取
        hasClaimed[msg.sender] = true;

        MYNFT nft = MYNFT(NftAddress);
        nft.mint(msg.sender, tokenId);

        emit NftClaimed(msg.sender, tokenId);
        tokenId++;
    }

    // 管理员功能：设置新的 Merkle root
    function setMerkleRoot(bytes32 _newMerkleRoot) external onlyOwner {
        merkleRoot = _newMerkleRoot;
    }

    // 管理员功能：提取合约中的以太币
    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // 管理员功能：提取合约中的 ERC20 代币
    function withdrawERC20() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(owner(), balance), "Transfer failed");
    }
    

    // 确保合约可以接收 ETH
    receive() external payable {}
}