#[cfg(test)]
mod token_sender_test {
    use token_sender::token_sender::sender::{
        TokenSender, ITokenSenderDispatcher, ITokenSenderDispatcherTrait, TransferRequest
    };

    use token_sender::tests::mock_erc20::MockERC20;
    use token_sender::erc20::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};

    use starknet::testing::{set_caller_address, set_contract_address, set_block_timestamp};

    use starknet::{
        contract_address_const, get_block_info, ContractAddress, Felt252TryIntoContractAddress,
        TryInto, Into, OptionTrait, class_hash::Felt252TryIntoClassHash
    };

    use starknet::syscalls::deploy_syscall;
    use array::ArrayTrait;
    use result::ResultTrait;
    use serde::Serde;

    use debug::PrintTrait;


    const NAME: felt252 = 111;
    const SYMBOL: felt252 = 222;
    fn setup() -> (ContractAddress, IERC20Dispatcher, ITokenSenderDispatcher) {
        let account: ContractAddress = contract_address_const::<0xDEADBEAF>();
        set_caller_address(account);

        let initial_supply: u256 = u256 { low: 1000000000_u128, high: 0_u128 };

        // Deploy ERC20
        let mut calldata = ArrayTrait::new();
        NAME.serialize(ref calldata);
        SYMBOL.serialize(ref calldata);
        18.serialize(ref calldata);
        initial_supply.serialize(ref calldata);
        account.serialize(ref calldata);

        let (erc20_address, _) = deploy_syscall(
            MockERC20::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();

        // deploy sender
        let mut calldata = ArrayTrait::new();
        let (remover_address, _) = deploy_syscall(
            TokenSender::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();
        let erc20 = IERC20Dispatcher { contract_address: erc20_address };
        let token_sender = ITokenSenderDispatcher { contract_address: remover_address };

        (account, erc20, token_sender)
    }

    #[test]
    #[available_gas(10000000)]
    fn test_constructor() {
        let (_, _, _) = setup();
    }

    #[test]
    #[available_gas(10000000)]
    fn test_multisend() {
        let (account, erc20, token_sender) = setup();
        let amount: u256 = 1.into();

        let dest1: ContractAddress = contract_address_const::<0x111>();
        let dest2: ContractAddress = contract_address_const::<0x222>();

        // start prank account
        set_contract_address(account);
        erc20.approve(token_sender.contract_address, amount * 2);

        assert(
            erc20.allowance(account, token_sender.contract_address) == amount * 2,
            'Allowance not set'
        );

        let request1 = TransferRequest { recipient: dest1, amount: amount };
        let request2 = TransferRequest { recipient: dest2, amount: amount };

        let mut transfer_list = ArrayTrait::<TransferRequest>::new();
        transfer_list.append(request1);
        transfer_list.append(request2);

        // move all tokens
        token_sender.multisend(erc20.contract_address, transfer_list);
        assert(
            erc20.allowance(account, token_sender.contract_address) == 0, 'Allowance not changed'
        );

        let dest_balance = erc20.balance_of(dest1);
        assert(dest_balance == amount, 'Did not move');
    }
}
