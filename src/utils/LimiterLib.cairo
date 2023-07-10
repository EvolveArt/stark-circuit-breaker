#[derive(Drop, Copy, PartialEq)]
enum LimitStatus {
    Uninitialized: felt252,
    Inactive: felt252,
    Ok: felt252,
    Triggered: felt252
}

use circuit_breaker::circuit_breaker::structs::{Limiter, LiqChangeNode};
use starknet::{get_block_timestamp};
use alexandria_math::signed_integers::i129;

const BPS_DENOMINATOR: u256 = 10000_u256;
const U64_MAX: u64 = 18446744073709551615;

#[generate_trait]
impl LimiterImpl of LimiterTrait {
    fn init(ref self: Limiter, minLiqRetainedBps: u256, limitBeginThreshold: u256) {
        assert(minLiqRetainedBps != 0 && minLiqRetainedBps <= BPS_DENOMINATOR, 'Invalid Threshold');

        assert(!self.initialized(), 'Already initialized');
        self.min_liq_retained_bps = minLiqRetainedBps;
        self.limit_begin_threshold = limitBeginThreshold;
    }

    fn updateParams(ref self: Limiter, minLiqRetainedBps: u256, limitBeginThreshold: u256) {
        assert(minLiqRetainedBps != 0 && minLiqRetainedBps <= BPS_DENOMINATOR, 'Invalid Threshold');

        assert(self.initialized(), 'Already initialized');
        self.min_liq_retained_bps = minLiqRetainedBps;
        self.limit_begin_threshold = limitBeginThreshold;
    }

    fn recordChange(ref self: Limiter, amount: i129, withdrawal_period: u64, tick_length: u64) {
        // If token does not have a rate limit, do nothing
        if (!self.initialized()) {
            return;
        }

        let current_tick_timestamp = self.getTickTimestamp(get_block_timestamp(), tick_length);
        self.liq_in_period += amount;

        let list_head = self.list_head;
        if (list_head == 0) {
            // if there is no head, set the head to the new inflow
            self.list_head = current_tick_timestamp;
            self.list_tail = current_tick_timestamp;
        // limiter.list_nodes[current_tick_timestamp] = LiqChangeNode({amount, next_timestamp: 0});
        } else {
            // if there is a head, check if the new inflow is within the period
            // if it is, add it to the head
            // if it is not, add it to the tail
            if (get_block_timestamp() - list_head >= withdrawal_period) {
                self.sync(withdrawal_period, Option::Some(U64_MAX));
            }

            // check if tail is the same as block.timestamp (multiple txs in same block)
            let list_tail = self.list_tail;
            if (list_tail == current_tick_timestamp) { // add amount
            // limiter.list_nodes[current_tick_timestamp].amount += amount;
            } else {
                // add to tail
                // limiter.list_nodes[list_tail].next_timestamp = current_tick_timestamp;
                // limiter.list_nodes[current_tick_timestamp] = LiqChangeNode({amount, next_timestamp: 0});
                self.list_tail = current_tick_timestamp;
            }
        }
    }

    fn status(self: @Limiter) -> LimitStatus {
        if (!self.initialized()) {
            return LimitStatus::Uninitialized(0);
        }
        let current_liq: i129 = *self.liq_total;

        // Only enforce rate limit if there is significant liquidity
        if (self.limit_begin_threshold > current_liq.into()) {
            return LimitStatus::Inactive(0);
        }

        let future_liq = current_liq + *self.liq_in_period;
        let min_liq: i129 = (current_liq * self.min_liq_retained_bps.into())
            / BPS_DENOMINATOR.into();

        let mut result = LimitStatus::Inactive(0);
        if (future_liq < min_liq) {
            result = LimitStatus::Triggered(0)
        } else {
            result = LimitStatus::Ok(0)
        }

        return result;
    }

    fn sync(ref self: Limiter, withdrawal_period: u64, total_iters: Option<u64>) {
        let current_head = self.list_head;
        let total_change: i129 = i129 { inner: 0, sign: false };
        let iter = 0;
    }

    fn initialized(self: @Limiter) -> bool {
        *self.min_liq_retained_bps > 0_u256
    }

    fn getTickTimestamp(self: @Limiter, t: u64, tick_length: u64) -> u64 {
        t - (t % tick_length)
    }
}
