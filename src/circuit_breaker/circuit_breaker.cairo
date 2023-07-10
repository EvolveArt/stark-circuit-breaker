use core::zeroable::Zeroable;
use core::array::SpanTrait;
use core::box::BoxTrait;
use core::option::OptionTrait;
#[starknet::contract]
mod CircuitBreaker {
    use starknet::{get_caller_address, get_contract_address, ContractAddress, get_block_timestamp};
    use circuit_breaker::circuit_breaker::interface::ICircuitBreaker;
    use circuit_breaker::circuit_breaker::structs::{Limiter, LiqChangeNode};
    use circuit_breaker::tests::mocks::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use array::ArrayTrait;
    use option::OptionTrait;
    use box::BoxTrait;
    use zeroable::Zeroable;


    #[storage]
    struct Storage {
        _admin: ContractAddress,
        _is_protected_contract: LegacyMap<ContractAddress, bool>,
        _is_operational: bool,
        _is_rate_limited: bool,
        _rate_limit_cooldown_period: u64,
        _liquidity_tick_length: u64,
        _withdrawal_period: u64,
        _grace_period_end_timestamp: u64,
        _last_rate_limit_timestamp: u64,
        _token_limiters: LegacyMap<ContractAddress, Limiter>
    }

    //
    // Modifiers
    //

    #[generate_trait]
    impl ModifierImpl of ModifierTrait {
        fn _only_admin(self: @ContractState) {
            let caller = get_caller_address();
            assert(self._admin.read() == caller, 'Not Admin');
        }

        fn _only_protected(self: @ContractState) {
            let caller = get_caller_address();
            assert(!self._is_protected_contract.read(caller), 'Not Protected');
        }

        fn _only_operationnal(self: @ContractState) {
            assert(!self._is_operational.read(), 'Exploited');
        }
    }

    //
    // Constructor
    //

    //  @notice gracePeriod refers to the time after a rate limit trigger and then overriden where withdrawals are
    //  still allowed.
    //  @dev For example a false positive rate limit trigger, then it is overriden, so withdrawals are still
    //  allowed for a period of time.
    //  Before the rate limit is enforced again, it should be set to be at least your largest
    //  withdrawalPeriod length
    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin_: starknet::ContractAddress,
        rate_limit_cooldown_period_: u64,
        withdrawal_period_: u64,
        liquidity_tick_length_: u64
    ) {
        self._admin.write(admin_);
        self._rate_limit_cooldown_period.write(rate_limit_cooldown_period_);
        self._withdrawal_period.write(withdrawal_period_);
        self._liquidity_tick_length.write(liquidity_tick_length_);
    }

    ////////////////////////////////////////////////////////////////
    //                         FUNCTIONS                          //
    ////////////////////////////////////////////////////////////////

    #[external(v0)]
    impl CircuitBreakerImpl of ICircuitBreaker<ContractState> {
        fn registerAsset(
            ref self: ContractState,
            _asset: ContractAddress,
            _minLiqRetainedBps: felt252,
            _limitBeginThreshold: felt252
        ) {
            self._only_admin();

            let mut token_limiter = self._token_limiters.read(_asset);
            token_limiter.init(_minLiqRetainedBps, _limitBeginThreshold);

            self
                .emit(
                    Event::AssetRegistered {
                        asset: _asset,
                        minLiqRetainedBps: _minLiqRetainedBps,
                        limitBeginThreshold: _limitBeginThreshold,
                    }
                );
        }

        fn updateAssetParams(
            ref self: ContractState,
            _asset: ContractAddress,
            _minLiqRetainedBps: felt252,
            _limitBeginThreshold: felt252
        ) {
            self._only_admin();

            let mut limiter = self._token_limiters.read(_asset);
            limiter.updateParams(_minLiqRetainedBps, _limitBeginThreshold);
            limiter.sync(self._withdrawal_period.read());
        }

        fn onTokenInflow(ref self: ContractState, _token: ContractAddress, _amount: u256) {
            self._only_protected();
            self._only_operationnal();

            self._onTokenInflow(_token, _amount);
        }

        fn onTokenOutflow(
            ref self: ContractState,
            _token: ContractAddress,
            _amount: u256,
            _recipient: ContractAddress,
            _revertOnRateLimit: bool
        ) {
            self._only_protected();
            self._only_operationnal();

            self._onTokenOutflow(_token, _amount, _recipient, _revertOnRateLimit);
        }

        fn claimLockedFunds(
            ref self: ContractState, _asset: ContractAddress, _recipient: ContractAddress
        ) {}
        fn setAdmin(ref self: ContractState, _newAdmin: ContractAddress) {
            self._only_admin();

            assert(_newAdmin.is_non_zero(), 'Invalid Address');
            self._admin.write(_newAdmin);
            self.emit(Event::AdminSet { new_admin: _newAdmin });
        }
        fn overrideRateLimit(ref self: ContractState) {
            self._only_admin();

            assert(self._is_rate_limited.read(), 'Not Rate Limited');
            self._is_rate_limited.write(false);

            // Allow the grace period to extend for the full withdrawal period to not trigger rate limit again
            // if the rate limit is removed just before the withdrawal period ends
            self
                ._grace_period_end_timestamp
                .write(self._last_rate_limit_timestamp.read() + self._withdrawal_period.read());
        }
        fn overrideExpiredRateLimit(ref self: ContractState) {
            assert(self._is_rate_limited.read(), 'Not Rate Limited');
            assert(
                get_block_timestamp()
                    - self
                        ._last_rate_limit_timestamp
                        .read() >= self
                        ._rate_limit_cooldown_period
                        .read(),
                'Cooldown not elapsed'
            );

            self._is_rate_limited.write(false);
        }
        fn addProtectedContracts(
            ref self: ContractState, _ProtectedContracts: Array<ContractAddress>
        ) {
            self._only_admin();

            let mut data_span = _ProtectedContracts.span();
            loop {
                match data_span.pop_front() {
                    Option::Some(address) => {
                        self._is_protected_contract.write(address, true);
                    },
                    Option::None(_) => {
                        break;
                    }
                }
            }
        }
        fn removeProtectedContracts(
            ref self: ContractState, _ProtectedContracts: Array<ContractAddress>
        ) {
            self._only_admin();

            let mut data_span = _ProtectedContracts.span();
            loop {
                match data_span.pop_front() {
                    Option::Some(address) => {
                        self._is_protected_contract.write(address, false);
                    },
                    Option::None(_) => {
                        break;
                    }
                }
            }
        }
        fn startGracePeriod(ref self: ContractState, _gracePeriodEndTimestamp: u64) {
            self._only_admin();

            assert(
                self._grace_period_end_timestamp.read() > get_block_timestamp(), 'Invalid Period'
            );
            self._grace_period_end_timestamp.write(_gracePeriodEndTimestamp);
            self
                .emit(
                    Event::GracePeriodStarted {
                        grace_period_end_timestamp: _gracePeriodEndTimestamp
                    }
                );
        }
        fn markAsNotOperational(ref self: ContractState) {
            self._only_admin();

            self._is_operational.write(false);
        }
        fn migrateFundsAfterExploit(
            ref self: ContractState,
            _assets: Array<ContractAddress>,
            _recoveryRecipient: ContractAddress
        ) {
            self._only_admin();

            assert(!self._is_operational.read(), 'Not Exploited');
            let mut data_span = _assets.span();
            loop {
                match data_span.pop_front() {
                    Option::Some(address) => {
                        let ERC20 = IERC20Dispatcher { contract_address: token };
                        let amount = ERC20.balance_of(this);

                        if (amount > 0) {
                            ERC20.transfer(_recoveryRecipient, amount);
                        }
                    },
                    Option::None(_) => {
                        break;
                    }
                }
            }
        }
        fn lockedFunds(
            self: @ContractState, recipient: ContractAddress, asset: ContractAddress
        ) -> u256 {}
        fn isProtectedContract(self: @ContractState, account: ContractAddress) -> bool {}
        fn admin(self: @ContractState) -> ContractAddress {}
        fn isRateLimited(self: @ContractState) -> bool {}
        fn rateLimitCooldownPeriod(self: @ContractState) -> u256 {}
        fn lastRateLimitTimestamp(self: @ContractState) -> u256 {}
        fn gracePeriodEndTimestamp(self: @ContractState) -> u256 {}
        fn isRateLimitTriggered(self: @ContractState, _asset: ContractAddress) -> bool {
            let limiter = self._token_limiters.read(_asset);
            limiter.status() == LimitStatus.Triggered
        }
        fn isInGracePeriod(self: @ContractState) -> bool {
            get_block_timestamp() <= self._grace_period_end_timestamp.read()
        }
        fn isOperational(self: @ContractState) -> bool {}
    }

    ////////////////////////////////////////////////////////////////
    //                         INTERNAL                           //
    ////////////////////////////////////////////////////////////////

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _onTokenInflow(ref self: ContractState, _token: ContractAddress, _amount: i129) {
            /// @dev uint256 could overflow into negative
            let mut limiter = self._token_limiters.read(_token);

            limiter
                .record_change(
                    _amount, self._withdrawal_period.read(), self._liquidity_tick_length.read()
                );
            self.emit(Event::AssetInflow { token: _token, amount: _amount });
        }

        fn _onTokenOutflow(
            ref self: ContractState,
            _token: ContractAddress,
            _amount: i129,
            _recipient: ContractAddress,
            _revert_on_rate_limit: bool
        ) {
            let mut limiter = self._token_limiters.read(_token);

            // Check if the token has enforced rate limited
            if (!limiter.initialized()) {
                // if it is not rate limited, just transfer the tokens
                let ERC20 = IERC20Dispatcher { contract_address: _token };
                ERC20.transfer(_recipient, _amount);
                return;
            }

            limiter
                .record_change(
                    _amount.neg(),
                    self._withdrawal_period.read(),
                    self._liquidity_tick_length.read()
                );

            // Check if currently rate limited, if so, add to locked funds claimable when resolved
            if (self._is_rate_limited.read()) {
                assert(!_revert_on_rate_limit, 'Rate Limited');

                let locked_funds = self._locked_funds.read(_recipient, _token);
                self._locked_funds.write(_recipient, _token, locked_funds + _amount);
                return;
            }

            // Check if rate limit is triggered after withdrawal and not in grace period
            // (grace period allows for withdrawals to be made if rate limit is triggered but overriden)
            if (limiter.status() == LimitStatus.Triggered && !self.isInGracePeriod()) {
                assert(!_revert_on_rate_limit, 'Rate Limited');

                let timestamp = get_block_timestamp();

                // if it is, set rate limited to true
                self._is_rate_limited.write(true);
                self._last_rate_limit_timestamp.write(timestamp);
                // add to locked funds claimable when resolved
                let locked_funds = self._locked_funds.read(_recipient, _token);
                self._locked_funds.write(_recipient, _token, locked_funds + _amount);

                self.emit(Event::AssetLimitBreached { token: _token, timestamp });

                return;
            }

            // if everything is good, transfer the tokens
            let ERC20 = IERC20Dispatcher { contract_address: _token };
            ERC20.transfer(_recipient, _amount);

            self
                .emit(
                    Event::AssetWithdraw { token: _token, recipient: _recipient, amount: _amount }
                );
        }
    }
}
