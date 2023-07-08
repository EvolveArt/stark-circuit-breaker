use core::traits::TryInto;
use starknet::ContractAddress;

#[starknet::interface]
trait ICircuitBreaker<TCircuit> {

    fn registerAsset(self: @TCircuit, _asset: ContractAddress, _metricThreshold: u256, _minAmountToLimit: u256);
    fn updateAssetParams(self: @TCircuit, _asset: ContractAddress, _metricThreshold: u256, _minAmountToLimit: u256);
    fn onTokenInflow(self: @TCircuit, _token: ContractAddress, _amount: u256);
    fn onTokenOutflow(self: @TCircuit, _token : ContractAddress, _amount: u256, _recipient: ContractAddress, _revertOnRateLimit: bool);
    fn onNativeAssetInflow(self: @TCircuit, _amount: u256);
    fn onNativeAssetOutflow(self: @TCircuit, _recipient: ContractAddress, _revertOnRateLimit: bool);
    fn claimLockedFunds(self: @TCircuit, _asset: ContractAddress, _recipient: ContractAddress);
    fn setAdmin(self: @TCircuit, _newAdmin: ContractAddress);
    fn overrideRateLimit(self: @TCircuit);
    fn overrideExpiredRateLimit(self: @TCircuit);
    fn addProtectedContracts(self: @TCircuit, _ProtectedContracts: Array<ContractAddress>) ;
    fn removeProtectedContracts(self: @TCircuit, _ProtectedContracts: Array<ContractAddress>) ;
    fn startGracePeriod(self: @TCircuit, _gracePeriodEndTimestamp: u256);
    fn markAsNotOperational(self: @TCircuit);
    fn migrateFundsAfterExploit(self: @TCircuit, _assets: Array<ContractAddress>, _recoveryRecipient: ContractAddress);
    fn lockedFunds(self: @TCircuit, recipient: ContractAddress, asset: ContractAddress) -> u256;
    fn isProtectedContract(self: @TCircuit, account: ContractAddress) -> bool;
    fn admin(self: @TCircuit) -> ContractAddress;
    fn isRateLimited(self: @TCircuit) -> bool;
    fn rateLimitCooldownPeriod(self: @TCircuit) -> u256;
    fn lastRateLimitTimestamp(self: @TCircuit) -> u256;
    fn gracePeriodEndTimestamp(self: @TCircuit) -> u256;
    fn isRateLimitTriggered(self: @TCircuit, _asset: ContractAddress) -> bool;
    fn isInGracePeriod(self: @TCircuit) -> bool;
    fn isOperational(self: @TCircuit) -> bool;
}