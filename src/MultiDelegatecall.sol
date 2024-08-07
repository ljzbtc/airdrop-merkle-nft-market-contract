// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiDelegatecall {
    function multiDelegatecall(
        bytes[] memory data
    ) external payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );
            if (!success) {
                // 如果调用失败，我们保存错误信息并继续执行
                results[i] = result;
            } else {
                results[i] = result;
            }
        }
    }
}