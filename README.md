# STARK circuit breaker ![PRs Welcome](https://img.shields.io/badge/PRs-welcome-green.svg) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/auditless/cairo-template/blob/main/LICENSE)

A circuit breaker is a mechanism that can prevent involuntary actions for Ethereum users. The goal is to establish a benchmark for smart contracts that can effectively prevent abnormally large token outflows from a DeFi protocol, triggering suspicion and potential intervention.
EIP-7265 introduces a mechanism where users can define the withdrawal threshold that activates the circuit breaker. The purpose of the circuit breaker is to automatically trigger a disruption when an abnormally high number of tokens are withdrawn from a protocol within a brief timeframe. We propose the integration of circuit breakers within Starknet accounts, allowing users to customize the asset outflows of their account and minimize losses when there is a breach.



This repo requires `Scarb 0.5.1`

Install Scarb with:

```
asdf plugin add scarb
asdf install scarb latest
```

(See more instructions for [asdf-scarb](https://github.com/software-mansion/asdf-scarb) installation

### Description

Account abstraction on Starknet allows for more manageable accounts. Features such as multisig, different signature schemes (i.e., biometric identification) or social recovery allows users to gain greater access to their account and hence, increase flexibility of their token management.
Pairing circuit breakers with guardians on account abstraction would allow users to increase control over their funds in case of a contract account breach. When creating accounts, users define guardians as well as maximum withdrawal amounts per account. The following logic applies when pairing circuit breakers and guardians on Starknet:
1. A user determines the maximum withdrawal amount per account
2. A user defines their guardian(s)
3. In the case of a breached account and the withdrawal of funds, the user will lose the amount of assets that they defined when the account was created (i.e., if account 2 has a maximum daily withdrawal of 55%, the user will lose 55% of their funds, assuming the hacker has aimed to remove the entirety of funds)
4. As the 55% cap is reached, the guardian of the user will be contacted
5. The guardian sends a message to the user asking if the 55% withdrawal was performed by the user of a hacker
6. If the withdrawal was not performed by the user, the guardian will instantly change the public key of the account to avoid any further withdrawals from the hacker
7. If the withdrawal was performed by the user, the guardian will not change the public key, and allow the user to withdrawal further amounts if wanted

![User journey of account breach with assistance of circuit breakers](https://files.gitbook.com/v0/b/gitbook-x-prod.appspot.com/o/spaces%2Fy5KeJYomgCy3lWFYyLpo%2Fuploads%2FeIP1ARosYwGk5BtJVQxK%2Fimage.png?alt=media&token=5e18bd61-efce-44de-ac37-3b12c70d8b5a)

![Voluntary VS involuntary withdrawl](https://files.gitbook.com/v0/b/gitbook-x-prod.appspot.com/o/spaces%2Fy5KeJYomgCy3lWFYyLpo%2Fuploads%2FiMFLQfkjhbspOcpmY7ND%2FScreenshot%202023-07-09%20at%2013.41.00.png?alt=media&token=ad9a977a-c8b9-49c6-bf29-ea1eaa8ea487)

## Account Abstraction on Starknet
Social recovery allows wallets to incorporate secure methods of replacing the controlling key of an account in the event of a lost or compromised private key. Guardians provide an extra layer of security and have a primary purpose of enhancing the account recovery process. If you lose your key, the guardians you defined when setting up your account can change the signing key to your new key, thereby granting you access once again. Guardians can take many shapes, including a MetaMask wallet, a Ledger hardware wallet, friends or family. Argent's two-factor authentication via phone or email can also be used.


## Changing the Public Key
```
set the guardian new public key
        fn set_guardian_public_key(ref self: ContractState, new_public_key: felt252) {
            // Modifiers
            self._only_self();
```
Here we first set the option of changing the Public Key, in case of an account breach. The `set_guardian_public_key` function is used to update the guardian's public key in the contract's state

## Trigger
```
 fn trigger_signer_escape(ref self: ContractState) {
            // Modifiers
            self._only_self();

            // Body
            let block_timestamp = starknet::get_block_timestamp();
            let active_date = block_timestamp + ESCAPE_SECURITY_PERIOD;

            self._signer_escape_activation_date.write(active_date);
```
The `trigger_signer_escape` function triggers the signer escape mechanism. It sets the `_only_self` modifier to ensure that the function can only be called by the contract itself. It then calculates the active date for the escape mechanism based on the current block timestamp and a predefined `ESCAPE_SECURITY_PERIOD`. It then modifies the contract's state by setting the signer escape activation date to the calculated active date and emits the corresponding event.


## Escape and update Public Key


```
fn escape_signer(ref self: ContractState, new_public_key: felt252) {
            // Modifiers
            self._only_self();

            // Body

            // Check if an escape is active
            let current_escape_activation_date = self._signer_escape_activation_date.read();
            let block_timestamp = starknet::get_block_timestamp();

            assert(current_escape_activation_date.is_non_zero(), 'Account: no escape');
            assert(current_escape_activation_date <= block_timestamp, 'Account: invalid escape');

            // Clear escape
            self._signer_escape_activation_date.write(0);

            // Check if new public key is valid
            assert(new_public_key.is_non_zero(), 'Account: new pk cannot be null');

            // Update signer public key
            self._signer_public_key.write(new_public_key);

            // Events
            self.emit(Event::SignerEscaped(SignerEscaped { new_public_key }));
        }
```
This code lies at the heart of the escape action when the cirtcuit breaker is triggered. If triggered and the action was not performed by the user, the public key will be changed, removing all access to the account from the hacker.



## Cancelling escape
```
fn cancel_escape(ref self: ContractState) {
            // Modifiers
            self._only_self();

            // Body
            let current_escape = self._signer_escape_activation_date.read();
            assert(current_escape.is_non_zero(), 'Account: no escape to cancel');

            self._signer_escape_activation_date.write(0);
            
             // Events
            self.emit(Event::EscapeCanceled(EscapeCanceled {}));
        }
```
The `cancel_escape` function is used to cancel an ongoing signer escape. It applies the `_only_self` modifier to ensure that the function can only be called by the contract itself. It retrieves the current signer escape activation date from the contract's state and asserts that it is non-zero, indicating an ongoing escape. If the assertion passes, it clears the escape by setting the signer escape activation date to zero 

## 

```
scarb test
```

## Running the scripts

The scripts use `starknet-rs` to interact with the network

Build the scripts with `cargo build --release`

### Thanks

If you like it then you shoulda put a ⭐ on it
