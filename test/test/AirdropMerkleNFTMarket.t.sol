// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/AirdropMerkleNFTMarket.sol";
import "src/ERC20Token.sol";
import "src/ERC721Token.sol";

contract AirdropMerkleNFTMarketTest is Test {
    AirdropMerkleNFTMarket public market;
    ERC20Token public token;
    ERC721Token public nft;
    address public user;
    uint256 public userPrivateKey;
    bytes32 public merkleRoot;

    function setUp() public {
        userPrivateKey = 0xA11CE;
        user = vm.addr(userPrivateKey);

        token = new ERC20Token("Test Token", "TT");
        nft = new ERC721Token("Test NFT", "TNFT");

        // 创建 Merkle 树
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256(abi.encodePacked(user));
        merkleRoot = getMerkleRoot(leaves);

        market = new AirdropMerkleNFTMarket(
            address(token),
            address(nft),
            merkleRoot
        );

        // 将 NFT 的所有权转移给 market 合约
        nft.changeOwner(address(market));

        // 给测试用户一些代币
        token.transfer(user, 1000 * 10 ** 18);
    }

    function testMulticallPermitAndClaim() public {
        vm.startPrank(user);
        
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(user);
        bytes32 permitHash = _getPermitHash(
            user,
            address(market),
            0.1 ether,
            nonce,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, permitHash);

        // 准备 permitPrePay 调用数据
        bytes memory permitCalldata = abi.encodeWithSelector(
            market.permitPrePay.selector,
            0.1 ether,
            deadline,
            v,
            r,
            s
        );

        // 准备 claimNftWithProof 调用数据
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256(abi.encodePacked(user));
        bytes32[] memory proof = getProof(leaves, 0);
        bytes memory claimCalldata = abi.encodeWithSelector(
            market.claimNftWithProof.selector,
            proof
        );

        // 准备 multicall 数据
        bytes[] memory multicallData = new bytes[](2);
        multicallData[0] = permitCalldata;
        multicallData[1] = claimCalldata;

        // 执行 multicall
        bytes[] memory results = market.multiDelegatecall(multicallData);

        // 验证结果
        require(results.length == 2, "Incorrect number of results");

        // 检查 permitPrePay 是否成功
        assertTrue(market.hasPrePaid(user), "Pre-pay failed");

        // 检查 claimNftWithProof 是否成功


        assertTrue(market.hasClaimed(user), "Claim failed");

        console.log("nftowenr",nft.ownerOf(0));
        console.log("user",user);
        assertEq(nft.ownerOf(0), user, "NFT not transferred to user");

        vm.stopPrank();
    }

    function testPermitPrePay() public {
        vm.startPrank(user);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(user);
        bytes32 permitHash = _getPermitHash(
            user,
            address(market),
            0.1 ether,
            nonce,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, permitHash);

        market.permitPrePay(0.1 ether, deadline, v, r, s);
        vm.stopPrank();

        assertTrue(market.hasPrePaid(user));
    }

    function testClaimNftWithProof() public {
        // 首先进行预付
        vm.startPrank(user);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(user);
        bytes32 permitHash = _getPermitHash(
            user,
            address(market),
            0.1 ether,
            nonce,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, permitHash);

        market.permitPrePay(0.1 ether, deadline, v, r, s);

        // 生成有效的 Merkle proof
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256(abi.encodePacked(user));
        bytes32[] memory proof = getProof(leaves, 0);

        market.claimNftWithProof(proof);
        vm.stopPrank();

        assertTrue(market.hasClaimed(user));
        assertEq(nft.ownerOf(0), user);
    }

    function testFailClaimWithoutPrePay() public {
        vm.prank(user);
        bytes32[] memory proof = new bytes32[](1);
        market.claimNftWithProof(proof);
    }

    function testFailClaimTwice() public {
        vm.startPrank(user);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(user);
        bytes32 permitHash = _getPermitHash(
            user,
            address(market),
            0.1 ether,
            nonce,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, permitHash);

        market.permitPrePay(0.1 ether, deadline, v, r, s);

        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256(abi.encodePacked(user));
        bytes32[] memory proof = getProof(leaves, 0);

        market.claimNftWithProof(proof);
        market.claimNftWithProof(proof); // 这应该失败
        vm.stopPrank();
    }

    function testWithdrawEther() public {
        // 向合约发送一些以太币
        (bool sent, ) = address(market).call{value: 1 ether}("");
        require(sent, "Failed to send Ether");

        uint256 initialBalance = address(this).balance;
        market.withdrawEther();
        uint256 finalBalance = address(this).balance;

        assertEq(finalBalance - initialBalance, 1 ether);
    }

    function testWithdrawERC20() public {
        // 向合约发送一些代币
        token.transfer(address(market), 100 * 10 ** 18);

        uint256 initialBalance = token.balanceOf(address(this));
        market.withdrawERC20();
        uint256 finalBalance = token.balanceOf(address(this));

        assertEq(finalBalance - initialBalance, 100 * 10 ** 18);
    }

    function getMerkleRoot(
        bytes32[] memory leaves
    ) internal pure returns (bytes32) {
        require(leaves.length > 0, "No leaves");
        while (leaves.length > 1) {
            bytes32[] memory newLeaves = new bytes32[]((leaves.length + 1) / 2);
            for (uint i = 0; i < newLeaves.length; i++) {
                if (2 * i + 1 < leaves.length) {
                    newLeaves[i] = keccak256(
                        abi.encodePacked(leaves[2 * i], leaves[2 * i + 1])
                    );
                } else {
                    newLeaves[i] = leaves[2 * i];
                }
            }
            leaves = newLeaves;
        }
        return leaves[0];
    }

    function getProof(
        bytes32[] memory leaves,
        uint index
    ) internal pure returns (bytes32[] memory) {
        require(leaves.length > 0, "No leaves");
        require(index < leaves.length, "Index out of bounds");

        bytes32[] memory proof = new bytes32[](log2(leaves.length));
        uint proofIndex = 0;

        while (leaves.length > 1) {
            bytes32[] memory newLeaves = new bytes32[]((leaves.length + 1) / 2);
            for (uint i = 0; i < newLeaves.length; i++) {
                if (2 * i + 1 < leaves.length) {
                    newLeaves[i] = keccak256(
                        abi.encodePacked(leaves[2 * i], leaves[2 * i + 1])
                    );
                    if (index / 2 == i) {
                        proof[proofIndex++] = index % 2 == 0
                            ? leaves[2 * i + 1]
                            : leaves[2 * i];
                    }
                } else {
                    newLeaves[i] = leaves[2 * i];
                }
            }
            leaves = newLeaves;
            index /= 2;
        }

        return proof;
    }

    function log2(uint256 x) internal pure returns (uint256) {
        require(x > 0, "log2(0) is undefined");
        uint256 n = 0;
        while (x > 1) {
            x >>= 1;
            n++;
        }
        return n;
    }

    function _getPermitHash(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        bytes32 PERMIT_TYPEHASH = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            spender,
                            value,
                            nonce,
                            deadline
                        )
                    )
                )
            );
    }

    receive() external payable {}
}
