use starknet::ContractAddress;
use array::Array;

#[starknet::interface]
trait IERC20<TContractState> {
    fn transferFrom(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256);
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256);

}

#[starknet::contract]
mod ProtectedContract {
    use super::{ContractAddress, Array, ICircuitBreaker, IERC20Dispatcher, IERC20DispatcherTrait};
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
        _token: IERC20Dispatcher,
        _sender: ContractAddress,
        _recipient: ContractAddress,
        _amount: u256
    ) { // // Transfer the tokens safely from sender to recipient
    _token.transferFrom(_sender, _recipient, _amount);
    // Call the circuitBreaker's onTokenInflow
    circuitBreaker.read().onTokenInflow(_token, _amount);
    }

    fn cbOutflowSafeTransfer(
        ref self: ContractState,
        _token: IERC20Dispatcher,
        _recipient: ContractAddress,
        _amount: u256,
        _revertOnRateLimit: bool
    ) { // // Transfer the tokens safely to the circuitBreaker
    _token.tranfer(address(circuitBreaker), _amount);
    // Call the circuitBreaker's onTokenOutflow
    circuitBreaker.read().onTokenOutflow(_token, _amount, _recipient, _revertOnRateLimit);
    }

    fn cbInflowNative(
        ref self: ContractState,
        _amount: u256
    ) { 
    // Transfer the tokens safely from sender to recipient
    circuitBreaker.read().onNativeAssetInflow(_amount);
    }

    fn cbOutflowNative(
        ref self: ContractState,
        _recipient: ContractAddress,
        _revertOnRateLimit: bool
    ) { 
    // Transfer the native tokens safely through the circuitBreaker
    circuitBreaker.read().onNativeAssetOutflow(_recipient, _revertOnRateLimit);
    }
}
