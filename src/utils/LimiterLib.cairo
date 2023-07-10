enum LimitStatus {
    Uninitialized: felt252,
    Inactive: felt252,
    Ok: felt252,
    Triggered: felt252
}

mod LimiterLib {
    use circuit_breaker::circuit_breaker::structs::{Limiter, LiqChangeNode};
    use starknet::{get_block_timestamp};
    use alexandria_math::signed_integers::i129;

    const BPS_DENOMINATOR: u256 = 10000_u256;

    #[generate_trait]
    impl LimiterImpl of LimiterTrait {
        fn init(ref limiter: Limiter, minLiqRetainedBps: u256, limitBeginThreshold: u256) {
            assert(
                minLiqRetainedBps != 0 && minLiqRetainedBps <= BPS_DENOMINATOR, 'Invalid Threshold'
            );

            assert(!self.initialized(limiter), 'Already initialized');
            limiter.min_liq_retained_bps = minLiqRetainedBps;
            limiter.limit_begin_threshold = limitBeginThreshold;
        }

        fn updateParams(ref limiter: Limiter, minLiqRetainedBps: u256, limitBeginThreshold: u256) {
            assert(
                minLiqRetainedBps != 0 && minLiqRetainedBps <= BPS_DENOMINATOR, 'Invalid Threshold'
            );

            assert(self.initialized(limiter), 'Already initialized');
            limiter.min_liq_retained_bps = minLiqRetainedBps;
            limiter.limit_begin_threshold = limitBeginThreshold;
        }

        fn recordChange(
            ref limiter: Limiter, amount: i129, withdrawal_period: u64, tick_length: u64
        ) {
            // If token does not have a rate limit, do nothing
            if (!self.initialized(limiter)) {
                return;
            }

            let current_tick_timestamp = self.getTickTimestamp(get_block_timestamp(), tick_length);
            limiter.liq_in_period += amount;

            let list_head = limiter.list_head;
            if (list_head == 0) {
                // if there is no head, set the head to the new inflow
                limiter.list_head = current_tick_timestamp;
                limiter.list_tail = current_tick_timestamp;
            // limiter.list_nodes[current_tick_timestamp] = LiqChangeNode({amount, next_timestamp: 0});
            } else {
                // if there is a head, check if the new inflow is within the period
                // if it is, add it to the head
                // if it is not, add it to the tail
                if (get_block_timestamp() - list_head >= withdrawal_period) {
                    self.sync(limiter, withdrawal_period, u64::MAX);
                }

                // check if tail is the same as block.timestamp (multiple txs in same block)
                let list_tail = limiter.list_tail;
                if (list_tail == current_tick_timestamp) {// add amount
                // limiter.list_nodes[current_tick_timestamp].amount += amount;
                } else {
                    // add to tail
                    // limiter.list_nodes[list_tail].next_timestamp = current_tick_timestamp;
                    // limiter.list_nodes[current_tick_timestamp] = LiqChangeNode({amount, next_timestamp: 0});
                    limiter.list_tail = current_tick_timestamp;
                }
            }
        }

        fn sync(ref limiter: Limiter, withdrawal_period: u64, total_iters: Option<u64>) {
            let current_head = limiter.list_head;
            let total_change: i129 = i129 { inner: 0, sign: false };
            let iter = 0;
        }

        fn initialized(limiter: @Limiter) -> bool {
            *limiter.min_liq_retained_bps > 0_u256
        }

        fn getTickTimestamp(t: u64, tick_length: u64) -> u64 {
            t - (t % tick_length)
        }
    }
}
