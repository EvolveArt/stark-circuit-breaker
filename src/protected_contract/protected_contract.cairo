#[starknet::contract]
mod ProtectedContract {
    use super::{ContractAddress, Array, ICircuitBreaker};
    use starknet::{get_block_timestamp, get_caller_address, contract_address_const};

    #[storage]
    struct Storage {
        circuitBreaker: ICircuitBreaker, 
    }

    #[constructor]
    fn constructor(ref self: ContractState, _circuitBreaker: ContractAddress) {
        self.circuitBreaker.write(ICircuitBreaker { contract_address: _circuitBreaker });
    }

    fn cbInflowSafeTransferFrom(
        ref self: ContractState,
        _token: ContractAddress,
        _sender: ContractAddress,
        _recipient: ContractAddress,
        _amount: u256
    ) {// // Transfer the tokens safely from sender to recipient
    // IERC20(_token).safeTransferFrom(_sender, _recipient, _amount);
    // // Call the circuitBreaker's onTokenInflow
    // circuitBreaker.onTokenInflow(_token, _amount);
    }

    fn cbOutflowSafeTransfer(
        ref self: ContractState,
        _token: ContractAddress,
        _recipient: ContractAddress,
        _amount: u256,
        _revertOnRateLimit: bool
    ) {// // Transfer the tokens safely to the circuitBreaker
    // IERC20(_token).safeTransfer(address(circuitBreaker), _amount);
    // // Call the circuitBreaker's onTokenOutflow
    // circuitBreaker.onTokenOutflow(_token, _amount, _recipient, _revertOnRateLimit);
    }

    fn cbInflowNative(ref self: ContractState) {// // Transfer the tokens safely from sender to recipient
    // circuitBreaker.onNativeAssetInflow(msg.value);
    }

    fn cbOutflowNative(
        ref self: ContractState,
        _recipient: ContractAddress,
        _amount: u256,
        _revertOnRateLimit: bool
    ) {// // Transfer the native tokens safely through the circuitBreaker
    // circuitBreaker.onNativeAssetOutflow{value: _amount}(_recipient, _revertOnRateLimit);
    }
}
