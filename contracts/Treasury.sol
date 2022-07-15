// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./TreasuryStorage.sol";

import "./libraries/SafeMath.sol";
import "./libraries/SafeERC20.sol";

// import "./interfaces/IERC20.sol";

import "./interfaces/IERC20Metadata.sol";
import "./interfaces/ITOS.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/ITOSValueCalculator.sol";

import "./common/ProxyAccessCommon.sol";


contract Treasury is 
    TreasuryStorage, 
    ProxyAccessCommon, 
    ITreasury 
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Deposit(address indexed token, uint256 amount, uint256 value);
    event Withdrawal(address indexed token, uint256 amount, uint256 value);
    event Minted(address indexed caller, address indexed recipient, uint256 amount);
    event Permissioned(address addr, STATUS indexed status, bool result);
    event ReservesAudited(uint256 indexed totalReserves);

    constructor() {
    }

    //uniswapV3 LP token을 deposit할 수 있어야함
    //uniswapV3 LP token을 backing할 수 있어야함
    //uniswapV3 token을 manage할 수 있어야함, swap(TOS -> ETH) Treasury가 가지고 있는 물량 onlyPolicy , mint(treasury가 주인), increaseLiquidity(treasury물량을 씀) , collect(treasury가 받음), decreaseLiquidity(treasury한테 물량이 감)
    
    /**
     * @notice allow approved address to deposit an asset for TOS (token의 현재 시세에 맞게 입금하고 TOS를 받음)
     * @param _amount uint256
     * @param _token address
     * @param _tosERC20Pool address
     * @param _fee uint24
     * @param _profit uint256
     * @return send_ uint256
     */
    //erc20토큰을 받고 TOS를 준다.
    //amount = ? ERC20 ->  ?ERC20 * ?TOS/1ERC20 -> ??TOS
    function deposit(
        uint256 _amount,
        address _token,
        address _tosERC20Pool,
        uint24 _fee,
        uint256 _profit
    ) external override returns (uint256 send_) {
        if (permissions[STATUS.RESERVETOKEN][_token]) {
            require(permissions[STATUS.RESERVEDEPOSITOR][msg.sender], notApproved);
        } else if (permissions[STATUS.LIQUIDITYTOKEN][_token]) {
            require(permissions[STATUS.LIQUIDITYDEPOSITOR][msg.sender], notApproved);
        } else {
            revert(invalidToken);
        }

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        
        uint256 value = (_amount*ITOSValueCalculator(calculator).getTOSERC20PoolERC20Price(_token,_tosERC20Pool,_fee))/1e18;
        
        // mint TOS needed and store amount of rewards for distribution
        send_ = value.sub(_profit);
        ITOS(address(TOS)).mint(msg.sender, send_);

        //주었을때 backing에 미치는 영향은 무엇인가?
        totalReserves = totalReserves.add(value);

        emit Deposit(_token, _amount, value);
    }

    function depositTokenId(

    ) external {
        
    }

    //자기가 보유하고 있는 TOS를 burn시키구 그가치에 해당하는 token의 amount를 가지고 간다.
    //amount = ? TOS -> ?TOS * ?ERC20/1TOS -> ??ERC20
    function withdraw(
        uint256 _amount, 
        address _token,
        address _tosERC20Pool,
        uint24 _fee
    ) 
        external 
        override 
    {
        require(permissions[STATUS.RESERVETOKEN][_token], notAccepted); // Only reserves can be used for redemptions
        require(permissions[STATUS.RESERVESPENDER][msg.sender], notApproved);

        uint256 value = (_amount*ITOSValueCalculator(calculator).getTOSERC20PoolTOSPrice(_token,_tosERC20Pool,_fee))/1e18;
        ITOS(address(TOS)).burn(msg.sender, value);
        
        //뺏을때 backing에 미치는 영향은 무엇인가?
        totalReserves = totalReserves.sub(value);

        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit Withdrawal(_token, _amount, value);
    }

    //TOS mint 권한 및 통제 설정 필요
    function mint(address _recipient, uint256 _amount) external override {
        require(permissions[STATUS.REWARDMANAGER][msg.sender], notApproved);
        ITOS(address(TOS)).mint(_recipient, _amount);
        emit Minted(msg.sender, _recipient, _amount);
    }

    /* ========== MANAGERIAL FUNCTIONS ========== */

    /**
     * @notice enable permission from queue
     * @param _status STATUS
     * @param _address address
     */
    function enable(
        STATUS _status,
        address _address
    ) 
        external
        onlyPolicyOwner 
    {
        permissions[_status][_address] = true;

        (bool registered, ) = indexInRegistry(_address, _status);

        if (!registered) {
            registry[_status].push(_address);
        }

        emit Permissioned(_address, _status, true);
    }

    function approve(
        address _addr
    ) external onlyPolicyOwner {
        TOS.approve(_addr, 1e45);
    }

    /**
     *  @notice disable permission from address
     *  @param _status STATUS
     *  @param _toDisable address
     */
    function disable(STATUS _status, address _toDisable) external onlyPolicyOwner {
        permissions[_status][_toDisable] = false;
        emit Permissioned(_toDisable, _status, false);
    }
 
    /**
     * @notice check if registry contains address
     * @return (bool, uint256)
     */
    function indexInRegistry(address _address, STATUS _status) public view returns (bool, uint256) {
        address[] memory entries = registry[_status];
        for (uint256 i = 0; i < entries.length; i++) {
            if (_address == entries[i]) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    //지원하는 자산을 추가 시킴
    function addbackingList(address _address,address _tosPooladdress, uint24 _fee) external override onlyPolicyOwner {
        uint256 amount = IERC20(_address).balanceOf(address(this));
        backingList[backings.length] = amount;

        backings.push(
            Backing({
                erc20Address: _address,
                tosPoolAddress: _tosPooladdress,
                fee: _fee
            })
        );
    }


    //tokenId는 유동성만 증가 -> backingReserve에 들어가지않음
    function addLiquidityIdList(uint256 _tokenId, address _tosPoolAddress) external override onlyPolicyOwner {
        tokenIdList[listings.length] = _tokenId;

        listings.push(
            Listing({
                tokenId: _tokenId,
                tosPoolAddress: _tosPoolAddress
            })
        );
    }

    function liquidityUpdate() public {
        
    }


    //현재 지원하는 자산을 최신으로 업데이트 시킴
    function backingUpdate() public override {
        ETHbacking = address(this).balance;
        for (uint256 i = 0; i < backings.length; i++) {
            uint256 amount = IERC20(backings[i].erc20Address).balanceOf(address(this));
            backingList[i] = amount;
        }
    }

    //eth, weth, market에서 받은 자산 다 체크해야함
    //환산은 eth단위로 
    //Treasury에 있는 자산을 ETH로 환산하여서 합하여 리턴함
    // token * (? ETH/1TOS * ?TOS/1ERC20) -> ? token * ( ? ETH/1token) -> ? ETH
    function backingReserve() public view returns (uint256) {
        uint256 totalValue;
        uint256 tosETHPrice = ITOSValueCalculator(calculator).getWETHPoolTOSPrice();
        for(uint256 i = 0; i < backings.length; i++) {
            uint256 amount = IERC20(backings[i].erc20Address).balanceOf(address(this));
            uint256 tosERC20Price = ITOSValueCalculator(calculator).getTOSERC20PoolERC20Price(backings[i].erc20Address,backings[i].tosPoolAddress,backings[i].fee);
            totalValue = totalValue + ((amount * tosERC20Price * tosETHPrice)/1e18/1e18);
        }
        totalValue = totalValue + ETHbacking;
        return totalValue;
    }

    function enableStaking() public override view returns (uint256) {
        return TOS.balanceOf(address(this));
    }
}
