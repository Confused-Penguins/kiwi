#ifndef KIWI_WEB_SERVER_H
#define KIWI_WEB_SERVER_H

#include <Arduino.h>
#include <ESPAsyncWebServer.h>
#include "crypto_utils.h"
#include "nvs_storage.h"

// Nonce freshness window: 30 seconds
#define ROUTER_NONCE_TTL_MS 30000

struct RouterNonceCache {
    char nonce_hex[HEX_STRING_KEY_LEN];
    uint32_t created_ms;
    bool consumed;
};

void web_server_init(const char* device_id,
                     const uint8_t pubkey[ED25519_KEY_SIZE],
                     const uint8_t privkey[ED25519_KEY_SIZE],
                     const char* pubkey_hex);

void web_server_update_keys(const char* device_id,
                            const uint8_t pubkey[ED25519_KEY_SIZE],
                            const uint8_t privkey[ED25519_KEY_SIZE],
                            const char* pubkey_hex);

#endif // KIWI_WEB_SERVER_H
