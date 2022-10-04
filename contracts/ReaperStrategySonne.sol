// SPDX-License-Identifier: MIT

import './abstract/ReaperBaseStrategyv3.sol';
//import './interfaces/IUniswapRouter.sol';
import './interfaces/CErc20I.sol';
import './interfaces/IComptroller.sol';
import "./interfaces/IVeloRouter.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

pragma solidity 0.8.11;

/**
 * @dev This strategy will deposit and leverage a token on Sonne to maximize yield by farming reward tokens
 */
contract ReaperStrategySonne is ReaperBaseStrategyv3 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev Tokens Used:
     * {USDC} - Required for liquidity routing when doing swaps. Also used to charge fees on yield.
     * {SONNE} - The reward token for farming
     * {want} - The vault token the strategy is maximizing
     * {cWant} - The Sonne version of the want token
     */
    address public constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address public constant SONNE = 0x1DB2466d9F5e10D7090E7152B68d62703a2245F0;
    address public want;
    CErc20I public cWant;

    /**
     * @dev Third Party Contracts:
     * {VELO_ROUTER} - the Velodrome router
     * {comptroller} - Sonne contract to enter market and to claim Sonne tokens
     */
    address public constant VELO_ROUTER = 0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9;
    IComptroller public comptroller;

    /**
     * @dev Routes we take to swap tokens
     * {sonneToUsdcRoute} - Route we take to get from {SONNE} into {USDC}.
     * {usdcToWantRoute} - Route we take to get from {USDC} into {want}.
     */
    address[] public sonneToUsdcRoute;
    address[] public usdcToWantRoute;

    /**
     * @dev Sonne variables
     * {markets} - Contains the Sonne tokens to farm, used to enter markets and claim Sonne
     * {MANTISSA} - The unit used by the Compound protocol
     * {LTV_SAFETY_ZONE} - We will only go up to 98% of max allowed LTV for {targetLTV}
     */
    address[] public markets;
    uint256 public constant MANTISSA = 1e18;
    uint256 public constant LTV_SAFETY_ZONE = 0.98 ether;

    /**
     * @dev Strategy variables
     * {targetLTV} - The target loan to value for the strategy where 1 ether = 100%
     * {allowedLTVDrift} - How much the strategy can deviate from the target ltv where 0.01 ether = 1%
     * {balanceOfPool} - The total balance deposited into Sonne (supplied - borrowed)
     * {borrowDepth} - The maximum amount of loops used to leverage and deleverage
     * {minWantToLeverage} - The minimum amount of want to leverage in a loop
     * {withdrawSlippageTolerance} - Maximum slippage authorized when withdrawing
     */
    uint256 public targetLTV;
    uint256 public allowedLTVDrift;
    uint256 public balanceOfPool;
    uint256 public borrowDepth;
    uint256 public minWantToLeverage;
    uint256 public maxBorrowDepth;
    uint256 public minSonneToSell;
    uint256 public withdrawSlippageTolerance;

    /**
     * @dev Initializes the strategy. Sets parameters, saves routes, and gives allowances.
     * @notice see documentation for each variable above its respective declaration.
     */
    function initialize(
        address _vault,
        address _treasury,
        address[] memory _strategists,
        address[] memory _multisigRoles,
        address _soWant
    ) public initializer {
        __ReaperBaseStrategy_init(_vault, _treasury, _strategists, _multisigRoles);
        cWant = CErc20I(_soWant);
        markets = [_soWant];
        comptroller = IComptroller(cWant.comptroller());
        want = cWant.underlying();
        usdcToWantRoute = [USDC, want];
        sonneToUsdcRoute = [SONNE, USDC];

        targetLTV = 0.72 ether;
        allowedLTVDrift = 0.01 ether;
        balanceOfPool = 0;
        borrowDepth = 12;
        minWantToLeverage = 1000;
        maxBorrowDepth = 15;
        minSonneToSell = 1000;
        withdrawSlippageTolerance = 50;

        _giveAllowances();

        comptroller.enterMarkets(markets);
    }

    /**
     * @dev Withdraws funds and sents them back to the vault.
     * It withdraws {want} from Sonne
     * The available {want} minus fees is returned to the vault.
     */
    function _withdraw(uint256 _withdrawAmount) internal override doUpdateBalance {
        require(msg.sender == vault);

        uint256 _ltv = _calculateLTVAfterWithdraw(_withdrawAmount);

        if (_shouldLeverage(_ltv)) {
            // Strategy is underleveraged so can withdraw underlying directly
            _withdrawUnderlyingToVault(_withdrawAmount);
            _leverMax();
        } else if (_shouldDeleverage(_ltv)) {
            _deleverage(_withdrawAmount);

            // Strategy has deleveraged to the point where it can withdraw underlying
            _withdrawUnderlyingToVault(_withdrawAmount);
        } else {
            // LTV is in the acceptable range so the underlying can be withdrawn directly
            _withdrawUnderlyingToVault(_withdrawAmount);
        }
    }

    /**
     * @dev Calculates the LTV using existing exchange rate,
     * depends on the cWant being updated to be accurate.
     * Does not update in order provide a view function for LTV.
     */
    function calculateLTV() external view returns (uint256 ltv) {
        (, uint256 cWantBalance, uint256 borrowed, uint256 exchangeRate) = cWant.getAccountSnapshot(address(this));

        uint256 supplied = (cWantBalance * exchangeRate) / MANTISSA;

        if (supplied == 0 || borrowed == 0) {
            return 0;
        }

        ltv = (MANTISSA * borrowed) / supplied;
    }

    /**
     * @dev Emergency function to deleverage in case regular deleveraging breaks
     */
    function manualDeleverage(uint256 amount) external doUpdateBalance {
        _atLeastRole(STRATEGIST);
        require(cWant.redeemUnderlying(amount) == 0);
        require(cWant.repayBorrow(amount) == 0);
    }

    /**
     * @dev Emergency function to deleverage in case regular deleveraging breaks
     */
    function manualReleaseWant(uint256 amount) external doUpdateBalance {
        _atLeastRole(STRATEGIST);
        require(cWant.redeemUnderlying(amount) == 0);
    }

    /**
     * @dev Sets a new LTV for leveraging.
     * Should be in units of 1e18
     */
    function setTargetLtv(uint256 _ltv) external {
        if (!hasRole(KEEPER, msg.sender)) {
            _atLeastRole(STRATEGIST);
        }

        (, uint256 collateralFactorMantissa, ) = comptroller.markets(address(cWant));
        require(collateralFactorMantissa > _ltv + allowedLTVDrift);
        require(_ltv <= collateralFactorMantissa * LTV_SAFETY_ZONE / MANTISSA);
        targetLTV = _ltv;
    }

    /**
     * @dev Sets a new allowed LTV drift
     * Should be in units of 1e18
     */
    function setAllowedLtvDrift(uint256 _drift) external {
        _atLeastRole(STRATEGIST);
        (, uint256 collateralFactorMantissa, ) = comptroller.markets(address(cWant));
        require(collateralFactorMantissa > targetLTV + _drift);
        allowedLTVDrift = _drift;
    }

    /**
     * @dev Sets a new borrow depth (how many loops for leveraging+deleveraging)
     */
    function setBorrowDepth(uint8 _borrowDepth) external {
        _atLeastRole(STRATEGIST);
        require(_borrowDepth <= maxBorrowDepth);
        borrowDepth = _borrowDepth;
    }

    /**
     * @dev Sets the minimum reward the will be sold (too little causes revert from Uniswap)
     */
    function setMinSonneToSell(uint256 _minSonneToSell) external {
        _atLeastRole(STRATEGIST);
        minSonneToSell = _minSonneToSell;
    }


    /**
     * @dev Sets the minimum want to leverage/deleverage (loop) for
     */
    function setMinWantToLeverage(uint256 _minWantToLeverage) external {
        _atLeastRole(STRATEGIST);
        minWantToLeverage = _minWantToLeverage;
    }

    /**
     * @dev Sets the maximum slippage authorized when withdrawing
     */
    function setWithdrawSlippageTolerance(uint256 _withdrawSlippageTolerance) external {
        _atLeastRole(STRATEGIST);
        withdrawSlippageTolerance = _withdrawSlippageTolerance;
    }

    /**
     * @dev Sets the swap path to go from {USDC} to {want}.
     */
    function setUsdcToWantRoute(address[] calldata _newUsdcToWantRoute) external {
        _atLeastRole(STRATEGIST);
        require(_newUsdcToWantRoute[0] == USDC, "bad route");
        require(_newUsdcToWantRoute[_newUsdcToWantRoute.length - 1] == want, "bad route");
        delete usdcToWantRoute;
        usdcToWantRoute = _newUsdcToWantRoute;
    }

    /**
     * @dev Function that puts the funds to work.
     * It gets called whenever someone supplied in the strategy's vault contract.
     * It supplies {want} Sonne to farm {SONNE}
     */
    function _deposit() internal override doUpdateBalance {
        CErc20I(cWant).mint(balanceOfWant());
        uint256 _ltv = _calculateLTV();

        if (_shouldLeverage(_ltv)) {
            _leverMax();
        } else if (_shouldDeleverage(_ltv)) {
            _deleverage(0);
        }
    }

    /**
     * @dev Calculates the total amount of {want} held by the strategy
     * which is the balance of want + the total amount supplied to Sonne.
     */
    function balanceOf() public view override returns (uint256) {
        return balanceOfWant() + balanceOfPool;
    }

    /**
     * @dev Calculates the balance of want held directly by the strategy
     */
    function balanceOfWant() public view returns (uint256) {
        return IERC20Upgradeable(want).balanceOf(address(this));
    }

    /**
     * @dev Returns the current position in Sonne. Does not accrue interest
     * so might not be accurate, but the cWant is usually updated.
     */
    function getCurrentPosition() public view returns (uint256 supplied, uint256 borrowed) {
        (, uint256 cWantBalance, uint256 borrowBalance, uint256 exchangeRate) = cWant.getAccountSnapshot(address(this));
        borrowed = borrowBalance;

        supplied = (cWantBalance * exchangeRate) / MANTISSA;
    }

    /**
     * @dev Updates the balance. This is the state changing version so it sets
     * balanceOfPool to the latest value.
     */
    function updateBalance() public {
        uint256 supplyBalance = CErc20I(cWant).balanceOfUnderlying(address(this));
        uint256 borrowBalance = CErc20I(cWant).borrowBalanceCurrent(address(this));
        balanceOfPool = supplyBalance - borrowBalance;
    }

    /**
     * @dev Levers the strategy up to the targetLTV
     */
    function _leverMax() internal {
        uint256 supplied = cWant.balanceOfUnderlying(address(this));
        uint256 borrowed = cWant.borrowBalanceStored(address(this));

        uint256 realSupply = supplied - borrowed;
        uint256 newBorrow = _getMaxBorrowFromSupplied(realSupply, targetLTV);
        uint256 totalAmountToBorrow = newBorrow - borrowed;

        for (uint8 i = 0; i < borrowDepth && totalAmountToBorrow > minWantToLeverage; i++) {
            totalAmountToBorrow = totalAmountToBorrow - _leverUpStep(totalAmountToBorrow);
        }
    }

    /**
     * @dev Does one step of leveraging
     */
    function _leverUpStep(uint256 _withdrawAmount) internal returns (uint256) {
        if (_withdrawAmount == 0) {
            return 0;
        }

        uint256 supplied = cWant.balanceOfUnderlying(address(this));
        uint256 borrowed = cWant.borrowBalanceStored(address(this));
        (, uint256 collateralFactorMantissa, ) = comptroller.markets(address(cWant));
        uint256 canBorrow = (supplied * collateralFactorMantissa) / MANTISSA;

        canBorrow -= borrowed;

        if (canBorrow < _withdrawAmount) {
            _withdrawAmount = canBorrow;
        }

        if (_withdrawAmount > 10) {
            // borrow available amount
            CErc20I(cWant).borrow(_withdrawAmount);

            // deposit available want as collateral
            CErc20I(cWant).mint(balanceOfWant());
        }

        return _withdrawAmount;
    }

    /**
     * @dev Gets the maximum amount allowed to be borrowed for a given collateral factor and amount supplied
     */
    function _getMaxBorrowFromSupplied(uint256 wantSupplied, uint256 collateralFactor) internal pure returns (uint256) {
        return ((wantSupplied * collateralFactor) / (MANTISSA - collateralFactor));
    }

    /**
     * @dev Returns if the strategy should leverage with the given ltv level
     */
    function _shouldLeverage(uint256 _ltv) internal view returns (bool) {
        if (targetLTV >= allowedLTVDrift && _ltv < targetLTV - allowedLTVDrift) {
            return true;
        }
        return false;
    }

    /**
     * @dev Returns if the strategy should deleverage with the given ltv level
     */
    function _shouldDeleverage(uint256 _ltv) internal view returns (bool) {
        if (_ltv > targetLTV + allowedLTVDrift) {
            return true;
        }
        return false;
    }

    /**
     * @dev This is the state changing calculation of LTV that is more accurate
     * to be used internally.
     */
    function _calculateLTV() internal returns (uint256 ltv) {
        uint256 supplied = cWant.balanceOfUnderlying(address(this));
        uint256 borrowed = cWant.borrowBalanceStored(address(this));

        if (supplied == 0 || borrowed == 0) {
            return 0;
        }
        ltv = (MANTISSA * borrowed) / supplied;
    }

    /**
     * @dev Calculates what the LTV will be after withdrawing
     */
    function _calculateLTVAfterWithdraw(uint256 _withdrawAmount) internal returns (uint256 ltv) {
        uint256 supplied = cWant.balanceOfUnderlying(address(this));
        uint256 borrowed = cWant.borrowBalanceStored(address(this));
        supplied = supplied - _withdrawAmount;

        if (supplied == 0 || borrowed == 0) {
            return 0;
        }
        ltv = (uint256(1e18) * borrowed) / supplied;
    }

    /**
     * @dev Withdraws want to the strat by redeeming the underlying
     */
    function _withdrawUnderlying(uint256 _withdrawAmount) internal {
        uint256 initialWithdrawAmount = _withdrawAmount;
        uint256 supplied = cWant.balanceOfUnderlying(address(this));
        uint256 borrowed = cWant.borrowBalanceStored(address(this));
        uint256 realSupplied = supplied - borrowed;

        if (realSupplied == 0) {
            return;
        }

        if (_withdrawAmount > realSupplied) {
            _withdrawAmount = realSupplied;
        }

        uint256 tempColla = targetLTV + allowedLTVDrift;

        uint256 reservedAmount = 0;
        if (tempColla == 0) {
            tempColla = 1e15; // 0.001 * 1e18. lower we have issues
        }

        reservedAmount = (borrowed * MANTISSA) / tempColla;
        if (supplied >= reservedAmount) {
            uint256 redeemable = supplied - reservedAmount;
            uint256 balance = cWant.balanceOf(address(this));
            if (balance > 1) {
                if (redeemable < _withdrawAmount) {
                    _withdrawAmount = redeemable;
                }
            }
        }

        uint256 withdrawAmount = _withdrawAmount - 1;
        if(withdrawAmount < initialWithdrawAmount) {
            require(
                withdrawAmount >=
                    (initialWithdrawAmount *
                        (PERCENT_DIVISOR - withdrawSlippageTolerance)) /
                        PERCENT_DIVISOR
            );
        }

        CErc20I(cWant).redeemUnderlying(withdrawAmount);
    }

    /**
     * @dev Withdraws want to the vault by redeeming the underlying
     */
    function _withdrawUnderlyingToVault(uint256 _withdrawAmount) internal {
        _withdrawUnderlying(_withdrawAmount);
        IERC20Upgradeable(want).safeTransfer(vault, IERC20Upgradeable(want).balanceOf(address(this)));
    }

    /**
     * @dev For a given withdraw amount, figures out the new borrow with the current supply
     * that will maintain the target LTV
     */
    function _getDesiredBorrow(uint256 _withdrawAmount) internal returns (uint256 position) {
        //we want to use statechanging for safety
        uint256 supplied = cWant.balanceOfUnderlying(address(this));
        uint256 borrowed = cWant.borrowBalanceStored(address(this));

        //When we unwind we end up with the difference between borrow and supply
        uint256 unwoundSupplied = supplied - borrowed;

        //we want to see how close to collateral target we are.
        //So we take our unwound supplied and add or remove the _withdrawAmount we are are adding/removing.
        //This gives us our desired future undwoundDeposit (desired supply)

        uint256 desiredSupply = 0;
        if (_withdrawAmount > unwoundSupplied) {
            _withdrawAmount = unwoundSupplied;
        }
        desiredSupply = unwoundSupplied - _withdrawAmount;

        //(ds *c)/(1-c)
        uint256 num = desiredSupply * targetLTV;
        uint256 den = MANTISSA - targetLTV;

        uint256 desiredBorrow = num / den;
        if (desiredBorrow > 1e5) {
            //stop us going right up to the wire
            desiredBorrow = desiredBorrow - 1e5;
        }

        position = borrowed - desiredBorrow;
    }

    /**
     * @dev For a given withdraw amount, deleverages to a borrow level
     * that will maintain the target LTV
     */
    function _deleverage(uint256 _withdrawAmount) internal {
        uint256 newBorrow = _getDesiredBorrow(_withdrawAmount);

        // //If there is no deficit we dont need to adjust position
        // //if the position change is tiny do nothing
        if (newBorrow > minWantToLeverage) {
            uint256 i = 0;
            while (newBorrow > minWantToLeverage + 100) {
                newBorrow = newBorrow - _leverDownStep(newBorrow);
                i++;
                //A limit set so we don't run out of gas
                if (i >= borrowDepth) {
                    break;
                }
            }
        }
    }

    /**
     * @dev Deleverages one step
     */
    function _leverDownStep(uint256 maxDeleverage) internal returns (uint256 deleveragedAmount) {
        uint256 minAllowedSupply = 0;
        uint256 supplied = cWant.balanceOfUnderlying(address(this));
        uint256 borrowed = cWant.borrowBalanceStored(address(this));
        (, uint256 collateralFactorMantissa, ) = comptroller.markets(address(cWant));

        //collat ration should never be 0. if it is something is very wrong... but just incase
        if (collateralFactorMantissa != 0) {
            minAllowedSupply = (borrowed * MANTISSA) / collateralFactorMantissa;
        }
        uint256 maxAllowedDeleverageAmount = supplied - minAllowedSupply;

        deleveragedAmount = maxAllowedDeleverageAmount;

        if (deleveragedAmount >= borrowed) {
            deleveragedAmount = borrowed;
        }
        if (deleveragedAmount >= maxDeleverage) {
            deleveragedAmount = maxDeleverage;
        }
        uint256 exchangeRateStored = cWant.exchangeRateStored();
        //redeemTokens = redeemAmountIn * 1e18 / exchangeRate. must be more than 0
        //a rounding error means we need another small addition
        if (deleveragedAmount * MANTISSA >= exchangeRateStored && deleveragedAmount > 10) {
            deleveragedAmount -= 10; // Amount can be slightly off for tokens with less decimals (USDC), so redeem a bit less
            cWant.redeemUnderlying(deleveragedAmount);
            //our borrow has been increased by no more than maxDeleverage
            cWant.repayBorrow(deleveragedAmount);
        }
    }

    /**
     * @dev Core function of the strat, in charge of collecting and re-investing rewards.
     * @notice Assumes the deposit will take care of the TVL rebalancing.
     * 1. Claims {SONNE} from the comptroller.
     * 2. Swaps {SONNE} to {USDC}.
     * 3. Claims fees for the harvest caller and treasury.
     * 4. Swaps the {USDC} token for {want}
     * 5. Deposits.
     */
    function _harvestCore() internal override returns(uint256 callerFee) {
        _claimRewards();
        _swapRewardsToUsdc();
        callerFee = _chargeFees();
        _swapToWant();
        deposit();
    }

    /**
     * @dev Core harvest function.
     * Get rewards from markets entered
     */
    function _claimRewards() internal {
        CTokenI[] memory tokens = new CTokenI[](1);
        tokens[0] = cWant;

        comptroller.claimComp(address(this), tokens);
    }

    /// @dev Helper function to swap given a {_path} and an {_amount}.
    function _swap(address[] memory _path, uint256 _amount) internal {
        if (_amount != 0) {
            IVeloRouter router = IVeloRouter(VELO_ROUTER);
            IVeloRouter.route[] memory routes = new IVeloRouter.route[](_path.length - 1);

            uint256 prevRouteOutput = _amount;
            uint256 output;
            bool useStable;
            for (uint256 i = 0; i < routes.length; i++) {
                (output, useStable) = router.getAmountOut(prevRouteOutput, _path[i], _path[i + 1]);
                routes[i] = IVeloRouter.route({from: _path[i], to: _path[i + 1], stable: useStable});
                prevRouteOutput = output;
            }
            IERC20Upgradeable(_path[0]).safeIncreaseAllowance(VELO_ROUTER, _amount);
            router.swapExactTokensForTokens(_amount, 0, routes, address(this), block.timestamp);
        }
    }

    /**
     * @dev Core harvest function.
     * Swaps {SONNE} to {USDC}
     */
    function _swapRewardsToUsdc() internal {
        uint256 sonneBalance = IERC20Upgradeable(SONNE).balanceOf(address(this));
        if (sonneBalance >= minSonneToSell) {
            _swap(sonneToUsdcRoute, sonneBalance);
        }
    }

    /**
     * @dev Core harvest function.
     * Charges fees based on the amount of USDC gained from reward
     */
    function _chargeFees() internal returns(uint256 callFeeToUser) {
        uint256 usdcFee = (IERC20Upgradeable(USDC).balanceOf(address(this)) * totalFee) / PERCENT_DIVISOR;
        if (usdcFee != 0) {
            callFeeToUser = (usdcFee * callFee) / PERCENT_DIVISOR;
            uint256 treasuryFeeToVault = (usdcFee * treasuryFee) / PERCENT_DIVISOR;

            IERC20Upgradeable(USDC).safeTransfer(msg.sender, callFeeToUser);
            IERC20Upgradeable(USDC).safeTransfer(treasury, treasuryFeeToVault);
        }
    }

    /**
     * @dev Core harvest function.
     * Swaps {USDC} for {want}
     */
    function _swapToWant() internal {
        if (want == USDC) {
            return;
        }
        
        uint256 usdcBalance = IERC20Upgradeable(USDC).balanceOf(address(this));
        if (usdcBalance != 0) {
            _swap(usdcToWantRoute, usdcBalance);
        }
    }

    /**
     * @dev Withdraws all funds leaving rewards behind.
     */
    function _reclaimWant() internal override {
        _deleverage(type(uint256).max);
        _withdrawUnderlying(balanceOfPool);
    }

    /**
     * @dev Gives the necessary allowances to mint cWant, swap rewards etc
     */
    function _giveAllowances() internal {
        IERC20Upgradeable(want).safeIncreaseAllowance(
            address(cWant),
            type(uint256).max - IERC20Upgradeable(want).allowance(address(this), address(cWant))
        );
        IERC20Upgradeable(USDC).safeIncreaseAllowance(
            VELO_ROUTER,
            type(uint256).max - IERC20Upgradeable(USDC).allowance(address(this), VELO_ROUTER)
        );
        IERC20Upgradeable(SONNE).safeIncreaseAllowance(
            VELO_ROUTER,
            type(uint256).max - IERC20Upgradeable(SONNE).allowance(address(this), VELO_ROUTER)
        );
    }

    /**
     * @dev Removes all allowance that were given
     */
    function _removeAllowances() internal {
        IERC20Upgradeable(want).safeDecreaseAllowance(address(cWant), IERC20Upgradeable(want).allowance(address(this), address(cWant)));
        IERC20Upgradeable(USDC).safeDecreaseAllowance(VELO_ROUTER, IERC20Upgradeable(USDC).allowance(address(this), VELO_ROUTER));
        IERC20Upgradeable(SONNE).safeDecreaseAllowance(VELO_ROUTER, IERC20Upgradeable(SONNE).allowance(address(this), VELO_ROUTER));
    }

    /**
     * @dev Helper modifier for functions that need to update the internal balance at the end of their execution.
     */
    modifier doUpdateBalance {
        _;
        updateBalance();
    }
}
