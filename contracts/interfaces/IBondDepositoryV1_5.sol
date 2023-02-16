// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./IERC20.sol";
import "../libraries/LibBondDepositoryV1_5.sol";
import "../libraries/LibBondDepository.sol";

interface IBondDepositoryV1_5 {

    ///////////////////////////////////////
    /// onlyPolicyOwner
    //////////////////////////////////////

    /// @dev                        creates a new market type
    /// @param token                token address of deposit asset. For ETH, the address is address(0). Will be used in Phase 2 and 3
    /// @param marketInfos          [capacity, maxPayout, lowerPriceLimit, initialMaxPayout, capacityUpdatePeriod]
    ///                             capacity             maximum purchasable bond in TOS
    ///                             lowerPriceLimit     lowerPriceLimit
    ///                             initialMaxPayout    initial max payout
    ///                             capacityUpdatePeriod capacity update period(seconds)
    /// @param bonusRatesAddress    bonusRates logic address
    /// @param bonusRatesId         bonusRates id
    /// @param startTime            start time
    /// @param endTime              market closing time
    /// @param pathes               pathes for find out the price
    /// @return id_                 returns ID of new bond market
    function create(
        address token,
        uint256[4] calldata marketInfos,
        address bonusRatesAddress,
        uint256 bonusRatesId,
        uint32 startTime,
        uint32 endTime,
        bytes[] calldata pathes
    ) external returns (uint256 id_);


    /**
     * @dev                   change the market capacity
     * @param _marketId       marketId
     * @param _increaseFlag   if true, increase capacity, otherwise decrease capacity
     * @param _increaseAmount the capacity amount
     */
    function changeCapacity(
        uint256 _marketId,
        bool _increaseFlag,
        uint256 _increaseAmount
    )   external;


    /**
     * @dev                changes the market closeTime
     * @param _marketId    marketId
     * @param closeTime    closeTime
     */
    function changeCloseTime(
        uint256 _marketId,
        uint256 closeTime
    )   external ;

    /**
     * @dev                changes the market price
     * @param _marketId    marketId
     * @param _tosPrice    tosPrice
     */
    function changeLowerPriceLimit(
        uint256 _marketId,
        uint256 _tosPrice
    )   external ;

    /**
     * @dev                     changes the oralce library address
     * @param _oralceLibrary    oralce library address
     * @param _uniswapFactory   uniswapFactory address
     */
    function changeOracleLibrary(
        address _oralceLibrary,
        address _uniswapFactory
    )   external ;

    /**
     * @dev                             changes bonus rate info
     * @param _marketId                 market id
     * @param _bonusRatesAddress     bonus rates address
     * @param _bonusRatesId          bonus rates id
     */
    function changeBonusRateInfo(
        uint256 _marketId,
        address _bonusRatesAddress,
        uint256 _bonusRatesId
    )   external ;

    /**
     * @dev                             this event occurs when the price path info is updated
     * @param _marketId                 market id
     * @param pathes                    path for pricing
     */
    function changePricePathInfo(
        uint256 _marketId,
        bytes[] calldata pathes
    )   external ;

    /**
     * @dev        closes the market
     * @param _id  market id
     */
    function close(uint256 _id) external;

     /**
     * @dev             change remaining TOS tolerance
     * @param _amount   tolerance
     */
    function changeRemainingTosTolerance(uint256 _amount) external;

    ///////////////////////////////////////
    /// Anyone can use.
    //////////////////////////////////////

    /// @dev                        deposit with ether that does not earn sTOS
    /// @param _id                  market id
    /// @param _amount              amount of deposit in ETH
    /// @param _minimumTosPrice     the minimum tos price
    /// @return payout_             returns amount of TOS earned by the user
    function ETHDeposit(
        uint256 _id,
        uint256 _amount,
        uint256 _minimumTosPrice
    ) external payable returns (uint256 payout_ );


    /// @dev                        deposit with ether that earns sTOS
    /// @param _id                  market id
    /// @param _amount              amount of deposit in ETH
    /// @param _minimumTosPrice     the maximum tos price
    /// @param _lockWeeks           number of weeks for lock
    /// @return payout_             returns amount of TOS earned by the user
    function ETHDepositWithSTOS(
        uint256 _id,
        uint256 _amount,
        uint256 _minimumTosPrice,
        uint8 _lockWeeks
    ) external payable returns (uint256 payout_);


    ///////////////////////////////////////
    /// VIEW
    //////////////////////////////////////

    /// @dev                        returns information from active markets
    /// @return marketIds           array of total marketIds
    /// @return marketInfo          array of total market's information
    /// @return bonusRateInfo       array of total market's bonusRateInfos
    function getBonds() external view
        returns (
            uint256[] memory marketIds,
            LibBondDepositoryV1_5.MarketInfo[] memory marketInfo,
            LibBondDepositoryV1_5.BonusRateInfo[] memory bonusRateInfo
        );

    /// @dev                returns all generated marketIDs
    /// @return memory[]    returns marketList
    function getMarketList() external view returns (uint256[] memory) ;

    /// @dev                    returns the number of created markets
    /// @return                 Total number of markets
    function totalMarketCount() external view returns (uint256) ;

    /// @dev                    turns information about the market
    /// @param _marketId        market id
    /// @return market          market base information
    /// @return marketInfo      market information
    /// @return bonusInfo       bonus information
    /// @return pricePathes     pathes for price
    function viewMarket(uint256 _marketId) external view
        returns (
            LibBondDepository.Market memory market,
            LibBondDepositoryV1_5.MarketInfo memory marketInfo,
            LibBondDepositoryV1_5.BonusRateInfo memory bonusInfo,
            bytes[] memory pricePathes
            );

    /// @dev               checks whether a market is opened or not
    /// @param _marketId   market id
    /// @return closedBool true if market is open, false if market is closed
    function isOpened(uint256 _marketId) external view returns (bool closedBool);

    /// @dev                    get bonding price
    /// @param _marketId        market id
    /// @param _lockWeeks       lock weeks
    /// @param basePrice       base price
    /// @return bondingPrice    bonding price
    function getBondingPrice(uint256 _marketId, uint8 _lockWeeks, uint256 basePrice)
        external view
        returns (uint256 bondingPrice);


    /// @dev                    get base price
    /// @param _marketId        market id
    /// @return basePrice       base price
    /// @return lowerPriceLimit lower price limit
    /// @return uniswapPrice    uniswap price
    function getBasePrice(uint256 _marketId)
        external view
        returns (uint256 basePrice, uint256 lowerPriceLimit, uint256 uniswapPrice);

    function getUniswapPrice(uint256 _marketId)
        external view
        returns (uint256 uniswapPrice);

    /// @dev                        calculate the possible max capacity
    /// @param _marketId            market id
    /// @return periodicCapacity    the periodic capacity
    /// @return currentCapacity     the current capacity
    function possibleMaxCapacity(
        uint256 _marketId
    ) external view returns (uint256 periodicCapacity, uint256 currentCapacity);


    /// @dev                            calculate the sale periods
    /// @param _marketId                market id
    /// @return numberOfPeriods         number of periods
    /// @return numberOfPeriodsPassed   number of periods passed
    function salePeriod(
        uint256 _marketId
    ) external view returns (uint256 numberOfPeriods, uint256 numberOfPeriodsPassed);


}