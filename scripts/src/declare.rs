use envfile::EnvFile;
use std::{path::Path, sync::Arc};
use url::Url;

use eyre::Result;
use starknet::{
    accounts::{Account, SingleOwnerAccount},
    core::types::{
        contract::CompiledClass, contract::SierraClass, BlockId, BlockTag, FieldElement,
    },
    providers::{
        jsonrpc::{HttpTransport, JsonRpcClient},
        Provider,
    },
    signers::{LocalWallet, SigningKey},
};

pub async fn declare(sierra_file_path: String, casm_file_path: String) -> Result<()> {
    let envfile = EnvFile::new(&Path::new(".env"))?;

    let provider = JsonRpcClient::new(HttpTransport::new(
        Url::parse(envfile.get("STARKNET_RPC_URL").unwrap()).unwrap(),
    ));

    let chain_id = provider.chain_id().await.unwrap();

    // Sierra class artifact. Output of the `starknet-compile` command
    let contract_artifact: SierraClass =
        serde_json::from_reader(std::fs::File::open(sierra_file_path).unwrap()).unwrap();

    println!(
        "Contract Hash: {:#064x}",
        contract_artifact.class_hash().unwrap()
    );

    let casm_artifact: CompiledClass =
        serde_json::from_reader(std::fs::File::open(casm_file_path).unwrap()).unwrap();

    let compiled_class_hash = casm_artifact.class_hash().unwrap();

    let signer = LocalWallet::from(SigningKey::from_secret_scalar(
        FieldElement::from_hex_be(envfile.get("PRIVATE_KEY").unwrap()).unwrap(),
    ));
    // let address = FieldElement::from_hex_be(envfile.get("ACCOUNT_ADDRESS").unwrap()).unwrap();
    let address = FieldElement::from_hex_be(
        "0x5465aa79114f0415f95100cafeb4640b17bce2653810903738ac6c1a7694b6c",
    )
    .unwrap();

    // TODO: set testnet/mainnet based on provider
    let mut account = SingleOwnerAccount::new(provider, signer, address, chain_id);

    // `SingleOwnerAccount` defaults to checking nonce and estimating fees against the latest
    // block. Optionally change the target block to pending with the following line:
    account.set_block_id(BlockId::Tag(BlockTag::Pending));

    // We need to flatten the ABI into a string first
    let flattened_class = contract_artifact.flatten().unwrap();

    let result = account
        .declare(Arc::new(flattened_class), compiled_class_hash)
        .send()
        .await
        .unwrap();

    println!("Declared in Tx: {:#064x}", result.transaction_hash);

    Ok(())
}
