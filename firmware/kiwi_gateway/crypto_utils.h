#ifndef KIWI_CRYPTO_UTILS_H
#define KIWI_CRYPTO_UTILS_H

#include <Arduino.h>
#include <Ed25519.h>

// Static buffer sizes
#define ED25519_KEY_SIZE 32
#define ED25519_SIG_SIZE 64
#define NONCE_SIZE 32
#define HEX_STRING_KEY_LEN 65   // 64 + null terminator
#define HEX_STRING_SIG_LEN 129  // 128 + null terminator

// Canonical challenge prefixes matching Python and Flutter implementations
#define AUTH_CHALLENGE_PREFIX "KIWI-AUTH:v1:"
#define CLIENT_VERIFY_PREFIX  "KIWI-CLIENT:v1:"

// Zero-heap cryptographic helper interface
void crypto_init();
void crypto_generate_random_bytes(uint8_t* output, size_t length);
void crypto_generate_keypair(uint8_t public_key[ED25519_KEY_SIZE], uint8_t private_key[ED25519_KEY_SIZE]);
bool crypto_sign_client_nonce(const char* client_nonce_hex,
                              const uint8_t priv_key[ED25519_KEY_SIZE],
                              const uint8_t pub_key[ED25519_KEY_SIZE],
                              char out_signature_hex[HEX_STRING_SIG_LEN]);

bool crypto_verify_phone_signature(const char* router_nonce_hex,
                                   const char* phone_pubkey_hex,
                                   const char* signature_hex);

// Utility conversions (static buffer, no heap)
void crypto_bytes_to_hex(const uint8_t* bytes, size_t len, char* hex_out);
bool crypto_hex_to_bytes(const char* hex_in, uint8_t* bytes_out, size_t len);

#endif // KIWI_CRYPTO_UTILS_H
