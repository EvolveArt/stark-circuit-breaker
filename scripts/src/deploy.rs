use envfile::EnvFile;
use std::{path::Path, sync::Arc};
use url::Url;

use eyre::Result;
use starknet::{
    accounts::SingleOwnerAccount,
    contract::ContractFactory,
    core::types::{contract::SierraClass, BlockId, BlockTag, FieldElement},
    macros::felt,
    providers::{
        jsonrpc::{HttpTransport, JsonRpcClient},
        Provider,
    },
    signers::{LocalWallet, SigningKey},
};

pub async fn deploy() -> Result<()> {
    let envfile = EnvFile::new(&Path::new(".env"))?;

    let provider = JsonRpcClient::new(HttpTransport::new(
        Url::parse(envfile.get("STARKNET_RPC_URL").unwrap()).unwrap(),
    ));

    let chain_id = provider.chain_id().await.unwrap();

    // Sierra class artifact. Output of the `starknet-compile` command
    let contract_artifact: SierraClass = serde_json::from_reader(
        std::fs::File::open("./../target/dev/compiled_TokenSender.sierra.json").unwrap(),
    )
    .unwrap();

    let class_hash = contract_artifact.class_hash().unwrap();
    println!("Contract Hash: {:#064x}", class_hash);

    let signer = LocalWallet::from(SigningKey::from_secret_scalar(
        FieldElement::from_hex_be(envfile.get("PRIVATE_KEY").unwrap()).unwrap(),
    ));
    let address = FieldElement::from_hex_be(envfile.get("ACCOUNT_ADDRESS").unwrap()).unwrap();

    // TODO: set testnet/mainnet based on provider
    let mut account = SingleOwnerAccount::new(provider, signer, address, chain_id);

    // `SingleOwnerAccount` defaults to checking nonce and estimating fees against the latest
    // block. Optionally change the target block to pending with the following line:
    account.set_block_id(BlockId::Tag(BlockTag::Pending));

    let account = Arc::new(account);

    let contract_factory = ContractFactory::new(class_hash, account);
    let result = contract_factory
        .deploy(&vec![], felt!("1123"), false)
        .send()
        .await
        .expect("Unable to deploy contract");

    println!("Deploy in Tx: {:#064x}", result.transaction_hash);

    Ok(())
}
