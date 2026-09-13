#include "crypto_utils.h"
#include <esp_random.h>
#include <string.h>

// Static buffers for zero-heap operation
static uint8_t s_msg_buffer[128];
static uint8_t s_sig_buffer[ED25519_SIG_SIZE];
static uint8_t s_pub_buffer[ED25519_KEY_SIZE];

void crypto_init() {
    // Hardware RNG on ESP32 is automatically initialized
}

void crypto_generate_random_bytes(uint8_t* output, size_t length) {
    esp_fill_random(output, length);
}

void crypto_generate_keypair(uint8_t public_key[ED25519_KEY_SIZE], uint8_t private_key[ED25519_KEY_SIZE]) {
    // Generate private key seed using ESP32 hardware RNG
    esp_fill_random(private_key, ED25519_KEY_SIZE);
    
    // Derive corresponding Ed25519 public key using rweather/Crypto
    Ed25519::derivePublicKey(public_key, private_key);
}

void crypto_bytes_to_hex(const uint8_t* bytes, size_t len, char* hex_out) {
    static const char hex_digits[] = "0123456789abcdef";
    for (size_t i = 0; i < len; i++) {
        hex_out[i * 2]     = hex_digits[(bytes[i] >> 4) & 0x0F];
        hex_out[i * 2 + 1] = hex_digits[bytes[i] & 0x0F];
    }
    hex_out[len * 2] = '\0';
}

bool crypto_hex_to_bytes(const char* hex_in, uint8_t* bytes_out, size_t len) {
    if (!hex_in || strlen(hex_in) != len * 2) {
        return false;
    }
    for (size_t i = 0; i < len; i++) {
        char c1 = hex_in[i * 2];
        char c2 = hex_in[i * 2 + 1];
        
        uint8_t v1, v2;
        if (c1 >= '0' && c1 <= '9') v1 = c1 - '0';
        else if (c1 >= 'a' && c1 <= 'f') v1 = c1 - 'a' + 10;
        else if (c1 >= 'A' && c1 <= 'F') v1 = c1 - 'A' + 10;
        else return false;
        
        if (c2 >= '0' && c2 <= '9') v2 = c2 - '0';
        else if (c2 >= 'a' && c2 <= 'f') v2 = c2 - 'a' + 10;
        else if (c2 >= 'A' && c2 <= 'F') v2 = c2 - 'A' + 10;
        else return false;
        
        bytes_out[i] = (v1 << 4) | v2;
    }
    return true;
}

bool crypto_sign_client_nonce(const char* client_nonce_hex,
                              const uint8_t priv_key[ED25519_KEY_SIZE],
                              const uint8_t pub_key[ED25519_KEY_SIZE],
                              char out_signature_hex[HEX_STRING_SIG_LEN]) {
    if (!client_nonce_hex || strlen(client_nonce_hex) != 64) {
        return false;
    }

    // Assemble canonical message: "KIWI-AUTH:v1:<client_nonce_hex>"
    // Prefix length: 13, Nonce: 64, Total = 77 bytes
    const char* prefix = AUTH_CHALLENGE_PREFIX;
    size_t prefix_len = strlen(prefix);
    size_t nonce_len = strlen(client_nonce_hex);
    size_t total_len = prefix_len + nonce_len;

    if (total_len >= sizeof(s_msg_buffer)) {
        return false;
    }

    memcpy(s_msg_buffer, prefix, prefix_len);
    memcpy(s_msg_buffer + prefix_len, client_nonce_hex, nonce_len);

    // Sign message using static buffer
    Ed25519::sign(s_sig_buffer, priv_key, pub_key, s_msg_buffer, total_len);

    // Convert signature to hex output
    crypto_bytes_to_hex(s_sig_buffer, ED25519_SIG_SIZE, out_signature_hex);
    return true;
}

bool crypto_verify_phone_signature(const char* router_nonce_hex,
                                   const char* phone_pubkey_hex,
                                   const char* signature_hex) {
    if (!router_nonce_hex || !phone_pubkey_hex || !signature_hex) {
        return false;
    }
    if (strlen(router_nonce_hex) != 64 || strlen(phone_pubkey_hex) != 64 || strlen(signature_hex) != 128) {
        return false;
    }

    // Convert phone public key and signature to bytes
    if (!crypto_hex_to_bytes(phone_pubkey_hex, s_pub_buffer, ED25519_KEY_SIZE)) {
        return false;
    }
    if (!crypto_hex_to_bytes(signature_hex, s_sig_buffer, ED25519_SIG_SIZE)) {
        return false;
    }

    // Assemble canonical message: "KIWI-CLIENT:v1:<router_nonce_hex>"
    const char* prefix = CLIENT_VERIFY_PREFIX;
    size_t prefix_len = strlen(prefix);
    size_t nonce_len = strlen(router_nonce_hex);
    size_t total_len = prefix_len + nonce_len;

    if (total_len >= sizeof(s_msg_buffer)) {
        return false;
    }

    memcpy(s_msg_buffer, prefix, prefix_len);
    memcpy(s_msg_buffer + prefix_len, router_nonce_hex, nonce_len);

    // Verify using rweather Ed25519
    return Ed25519::verify(s_sig_buffer, s_pub_buffer, s_msg_buffer, total_len);
}
