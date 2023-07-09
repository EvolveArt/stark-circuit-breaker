use array::SpanSerde;

#[starknet::interface]
trait IMockDefiProtocol<TContractState> {
    fn deposit(ref self: TContractState, token: starknet::ContractAddress, amount: u256);

    fn withdrawal(ref self: TContractState, token: starknet::ContractAddress, amount: u256);

    fn depositNoCircuitBreaker(
        ref self: TContractState, token: starknet::ContractAddress, amount: u256
    );

    fn depositNative(ref self: TContractState);

    fn withdrawalNative(ref self: TContractState, amount: u256);
}

#[starknet::contract]
mod MockDeFiProtocol {
    use circuit_breaker::tests::mocks::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use circuit_breaker::circuit_breaker::circuit_breaker::CircuitBreaker;
    use starknet::{get_caller_address, get_contract_address};
    use super::IMockDefiProtocol;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    //
    // Constructor
    //

    #[constructor]
    fn constructor(
        ref self: ContractState, circuit_breaker: starknet::ContractAddress
    ) { // Initialize circuit breaker
    }

    #[external(v0)]
    impl MockDeFiProtocolImpl of IMockDefiProtocol<ContractState> {
        fn deposit(ref self: ContractState, token: starknet::ContractAddress, amount: u256) {
            // IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
            let state: CircuitBreaker::ContractState = CircuitBreaker::unsafe_new_contract_state();
            let caller = get_caller_address();
            let this = get_contract_address();
            CircuitBreaker::cbInflowSafeTransferFrom(token, caller, this, amount);
        // Your logic here
        }

        fn withdrawal(ref self: ContractState, token: starknet::ContractAddress, amount: u256) {
            //  Your logic here

            let mut self: CircuitBreaker::ContractState =
                CircuitBreaker::unsafe_new_contract_state();
            let caller = get_caller_address();
            let this = get_contract_address();
            CircuitBreaker::cbOutflowSafeTransfer(ref self: self, token, caller, amount, false);
        }

        fn depositNoCircuitBreaker(
            ref self: ContractState, token: starknet::ContractAddress, amount: u256
        ) {
            let caller = get_caller_address();
            let this = get_contract_address();
            let ERC20 = IERC20Dispatcher { contract_address: token };
            ERC20.transfer_from(caller, this, amount);
        // Your logic here
        }

        fn depositNative(ref self: ContractState) {
            let state: CircuitBreaker::ContractState = CircuitBreaker::unsafe_new_contract_state();
            CircuitBreaker::cbInflowNative();
        }

        fn withdrawalNative(ref self: ContractState, amount: u256) {
            let state: CircuitBreaker::ContractState = CircuitBreaker::unsafe_new_contract_state();
            let caller = get_caller_address();
            CircuitBreaker::cbOutflowNative(caller, amount, false);
        }
    }
}
