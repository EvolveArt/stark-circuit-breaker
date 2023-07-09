#[derive(Drop, Copy)]
struct LiqChangeNode {
    next_timestamp: u256,
    amount: i128,
}

#[derive(Drop, Copy)]
struct Limiter {
    min_liq_retained_bps: u256,
    limit_begin_threshold: u256,
    liq_total: i128,
    liq_in_period: i128,
    list_head: u256,
    list_tail: u256,
    // mapping(uint256 tick => LiqChangeNode node) listNodes;
}