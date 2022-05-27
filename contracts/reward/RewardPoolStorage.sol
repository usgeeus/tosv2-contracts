// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IUniswapV3Pool.sol";
import "../interfaces/IUniswapV3Factory.sol";
import "../interfaces/INonfungiblePositionManager.sol";
import "../interfaces/IRewardLPTokenManagerAction.sol";


contract RewardPoolStorage {

    IUniswapV3Pool public pool;
    address public token0;
    address public token1;
    address public tosAddress;

    IUniswapV3Factory public uniswapV3Factory;
    INonfungiblePositionManager public nonfungiblePositionManager;
    IRewardLPTokenManagerAction public rewardLPTokenManager;

    //tokenId -> StakeInfo
    //mapping(uint256 => LibStakePoolBase.StakeInfo) public stakedTokenInfo;

    // user -> tokenIds
    mapping(address => uint256[]) public userTokens;
    mapping(address => mapping(uint256 => uint256)) public userTokenIndexs;

    // [tokenIds]
    uint256[] public stakedTokensInPool;
    mapping(uint256 => uint256) public stakedTokensInPoolIndexs;


    uint256 public totalTOS;
    uint128 public totalLiquidity;

    modifier nonZero(uint256 value) {
        require(value > 0, "zero value");
        _;
    }
}