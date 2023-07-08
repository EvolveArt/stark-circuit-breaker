# Cairo Contract template with Scarb ![PRs Welcome](https://img.shields.io/badge/PRs-welcome-green.svg) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/auditless/cairo-template/blob/main/LICENSE)

Simple template of a Cairo 1.0 contract built with Scarb
The example shows a contract that receives an ERC20 address and a list of addresses to send tokens to

This repo requires `Scarb 0.5.1`

Install Scarb with:

```
asdf plugin add scarb
asdf install scarb latest
```

(See more instructions for [asdf-scarb](https://github.com/software-mansion/asdf-scarb) installation

### Disclaimer

This is just an example, more features will be added as the language is improved while keeping it minimal

## Building

```
scarb build
```

## Testing

```
scarb test
```

## Running the scripts

The scripts use `starknet-rs` to interact with the network

Build the scripts with `cargo build --release`

### Thanks

If you like it then you shoulda put a ⭐ on it
