#ifndef KIWI_NVS_STORAGE_H
#define KIWI_NVS_STORAGE_H

#include <Arduino.h>
#include "crypto_utils.h"

#define MAX_DEVICE_ID_LEN 32

struct GatewayCertData {
    char device_id[MAX_DEVICE_ID_LEN];
    char public_key_hex[HEX_STRING_KEY_LEN];
    char signature_hex[HEX_STRING_SIG_LEN];
    uint32_t issued_at;
    bool is_valid;
};

// Initializes Preferences and loads or generates gateway keypair
bool nvs_init(char out_device_id[MAX_DEVICE_ID_LEN],
              uint8_t out_pubkey[ED25519_KEY_SIZE],
              uint8_t out_privkey[ED25519_KEY_SIZE],
              char out_pubkey_hex[HEX_STRING_KEY_LEN]);

// Force regeneration of gateway keys (clears existing certificate)
bool nvs_regenerate_keys(char out_device_id[MAX_DEVICE_ID_LEN],
                         uint8_t out_pubkey[ED25519_KEY_SIZE],
                         uint8_t out_privkey[ED25519_KEY_SIZE],
                         char out_pubkey_hex[HEX_STRING_KEY_LEN]);

// Certificate management
bool nvs_save_certificate(const char* device_id,
                          const char* public_key_hex,
                          const char* signature_hex,
                          uint32_t issued_at);

bool nvs_load_certificate(GatewayCertData* cert_out);
bool nvs_has_certificate();
void nvs_clear_all();

#endif // KIWI_NVS_STORAGE_H
