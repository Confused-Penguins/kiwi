#include "web_server.h"
#include <ArduinoJson.h>

static AsyncWebServer s_server(80);

// Gateway identity reference pointers
static char s_device_id[MAX_DEVICE_ID_LEN];
static uint8_t s_privkey[ED25519_KEY_SIZE];
static uint8_t s_pubkey[ED25519_KEY_SIZE];
static char s_pubkey_hex[HEX_STRING_KEY_LEN];

// Cached single-use router challenge nonce
static RouterNonceCache s_cached_nonce = { "", 0, true };

// Helper to set standard CORS headers
static void set_cors_headers(AsyncWebServerResponse* response) {
    response->addHeader("Access-Control-Allow-Origin", "*");
    response->addHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    response->addHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

void web_server_update_keys(const char* device_id,
                            const uint8_t pubkey[ED25519_KEY_SIZE],
                            const uint8_t privkey[ED25519_KEY_SIZE],
                            const char* pubkey_hex) {
    memset(s_device_id, 0, sizeof(s_device_id));
    memset(s_pubkey_hex, 0, sizeof(s_pubkey_hex));
    strncpy(s_device_id, device_id, sizeof(s_device_id) - 1);
    memcpy(s_privkey, privkey, ED25519_KEY_SIZE);
    memcpy(s_pubkey, pubkey, ED25519_KEY_SIZE);
    strncpy(s_pubkey_hex, pubkey_hex, sizeof(s_pubkey_hex) - 1);
}

void web_server_init(const char* device_id,
                     const uint8_t pubkey[ED25519_KEY_SIZE],
                     const uint8_t privkey[ED25519_KEY_SIZE],
                     const char* pubkey_hex) {
    web_server_update_keys(device_id, pubkey, privkey, pubkey_hex);

    // 1. Global CORS Pre-flight Options Handler
    s_server.onNotFound([](AsyncWebServerRequest *request) {
        if (request->method() == HTTP_OPTIONS) {
            AsyncWebServerResponse *response = request->beginResponse(204);
            set_cors_headers(response);
            request->send(response);
        } else {
            AsyncWebServerResponse *response = request->beginResponse(404, "application/json", "{\"error\":\"Not Found\"}");
            set_cors_headers(response);
            request->send(response);
        }
    });

    // 2. Gateway Provisioning & Status Info: GET /api/v1/provision/status
    s_server.on("/api/v1/provision/status", HTTP_GET, [](AsyncWebServerRequest *request) {
        StaticJsonDocument<512> doc;
        doc["status"] = "online";
        doc["device_id"] = s_device_id;
        doc["public_key"] = s_pubkey_hex;
        doc["has_certificate"] = nvs_has_certificate();

        GatewayCertData cert;
        if (nvs_load_certificate(&cert)) {
            JsonObject c = doc.createNestedObject("certificate");
            c["device_id"] = cert.device_id;
            c["public_key"] = cert.public_key_hex;
            c["signature"] = cert.signature_hex;
            c["issued_at"] = cert.issued_at;
        }

        String output;
        serializeJson(doc, output);
        AsyncWebServerResponse *response = request->beginResponse(200, "application/json", output);
        set_cors_headers(response);
        request->send(response);
    });

    // 3. Direction 1 — Phone verifies Gateway: POST /api/v1/mutual_auth
    s_server.on("/api/v1/mutual_auth", HTTP_POST,
        [](AsyncWebServerRequest *request) {
            // Handled in onBody
        },
        NULL,
        [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
            StaticJsonDocument<512> in_doc;
            DeserializationError err = deserializeJson(in_doc, data, len);

            if (err) {
                AsyncWebServerResponse *response = request->beginResponse(400, "application/json", "{\"error\":\"Invalid JSON\"}");
                set_cors_headers(response);
                request->send(response);
                return;
            }

            const char* client_nonce = in_doc["client_nonce"];
            if (!client_nonce || strlen(client_nonce) != 64) {
                AsyncWebServerResponse *response = request->beginResponse(400, "application/json", "{\"error\":\"client_nonce must be 32 bytes (64 hex characters)\"}");
                set_cors_headers(response);
                request->send(response);
                return;
            }

            GatewayCertData cert;
            if (!nvs_load_certificate(&cert) || !cert.is_valid) {
                AsyncWebServerResponse *response = request->beginResponse(503, "application/json", "{\"error\":\"Gateway has not been provisioned with a valid signed certificate\"}");
                set_cors_headers(response);
                request->send(response);
                return;
            }

            // Static buffer for signature
            char sig_hex[HEX_STRING_SIG_LEN];
            if (!crypto_sign_client_nonce(client_nonce, s_privkey, s_pubkey, sig_hex)) {
                AsyncWebServerResponse *response = request->beginResponse(500, "application/json", "{\"error\":\"Cryptographic signing failure\"}");
                set_cors_headers(response);
                request->send(response);
                return;
            }

            // Generate fresh 32-byte router nonce for Direction 2
            uint8_t router_nonce_bytes[NONCE_SIZE];
            crypto_generate_random_bytes(router_nonce_bytes, NONCE_SIZE);
            crypto_bytes_to_hex(router_nonce_bytes, NONCE_SIZE, s_cached_nonce.nonce_hex);
            s_cached_nonce.created_ms = millis();
            s_cached_nonce.consumed = false;

            // Build JSON response
            StaticJsonDocument<768> out_doc;
            out_doc["signature"] = sig_hex;
            out_doc["router_nonce"] = s_cached_nonce.nonce_hex;

            JsonObject cert_obj = out_doc.createNestedObject("certificate");
            cert_obj["device_id"] = cert.device_id;
            cert_obj["public_key"] = cert.public_key_hex;
            cert_obj["signature"] = cert.signature_hex;
            cert_obj["issued_at"] = cert.issued_at;

            String resp_str;
            serializeJson(out_doc, resp_str);
            AsyncWebServerResponse *response = request->beginResponse(200, "application/json", resp_str);
            set_cors_headers(response);
            request->send(response);
        }
    );

    // 4. Direction 2 — Gateway verifies Phone: POST /api/v1/client_verify
    s_server.on("/api/v1/client_verify", HTTP_POST,
        [](AsyncWebServerRequest *request) {
            // Handled in onBody
        },
        NULL,
        [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
            StaticJsonDocument<512> in_doc;
            DeserializationError err = deserializeJson(in_doc, data, len);

            if (err) {
                AsyncWebServerResponse *response = request->beginResponse(400, "application/json", "{\"error\":\"Invalid JSON\"}");
                set_cors_headers(response);
                request->send(response);
                return;
            }

            const char* phone_pubkey = in_doc["phone_public_key"];
            const char* signature = in_doc["signature"];
            const char* router_nonce = in_doc["router_nonce"];

            if (!phone_pubkey || !signature || !router_nonce) {
                AsyncWebServerResponse *response = request->beginResponse(400, "application/json", "{\"error\":\"Missing required fields: phone_public_key, signature, router_nonce\"}");
                set_cors_headers(response);
                request->send(response);
                return;
            }

            // Check single-use nonce freshness & validity
            if (s_cached_nonce.consumed || strcmp(router_nonce, s_cached_nonce.nonce_hex) != 0) {
                AsyncWebServerResponse *response = request->beginResponse(403, "application/json", "{\"status\":\"rejected\",\"reason\":\"Nonce consumed or mismatch\"}");
                set_cors_headers(response);
                request->send(response);
                return;
            }

            // Check TTL expiration (30 seconds)
            if ((millis() - s_cached_nonce.created_ms) > ROUTER_NONCE_TTL_MS) {
                s_cached_nonce.consumed = true;
                AsyncWebServerResponse *response = request->beginResponse(403, "application/json", "{\"status\":\"rejected\",\"reason\":\"Nonce expired\"}");
                set_cors_headers(response);
                request->send(response);
                return;
            }

            // Mark single-use nonce as consumed immediately to prevent replay
            s_cached_nonce.consumed = true;

            // Verify phone's Ed25519 signature
            bool valid_sig = crypto_verify_phone_signature(router_nonce, phone_pubkey, signature);
            if (valid_sig) {
                AsyncWebServerResponse *response = request->beginResponse(200, "application/json", "{\"status\":\"authorized\"}");
                set_cors_headers(response);
                request->send(response);
            } else {
                AsyncWebServerResponse *response = request->beginResponse(403, "application/json", "{\"status\":\"rejected\",\"reason\":\"Invalid client signature\"}");
                set_cors_headers(response);
                request->send(response);
            }
        }
    );

    // 5. Certificate Import Provisioning: POST /api/v1/provision/cert
    s_server.on("/api/v1/provision/cert", HTTP_POST,
        [](AsyncWebServerRequest *request) {
            // Handled in onBody
        },
        NULL,
        [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
            StaticJsonDocument<512> in_doc;
            DeserializationError err = deserializeJson(in_doc, data, len);

            if (err) {
                AsyncWebServerResponse *response = request->beginResponse(400, "application/json", "{\"error\":\"Invalid JSON\"}");
                set_cors_headers(response);
                request->send(response);
                return;
            }

            const char* dev_id = in_doc["device_id"];
            const char* pub_key = in_doc["public_key"];
            const char* sig = in_doc["signature"];
            uint32_t issued_at = in_doc["issued_at"] | 0;

            if (!dev_id || !pub_key || !sig || issued_at == 0) {
                AsyncWebServerResponse *response = request->beginResponse(400, "application/json", "{\"error\":\"Missing certificate fields\"}");
                set_cors_headers(response);
                request->send(response);
                return;
            }

            // Ensure certificate belongs to this gateway's public key
            if (strcasecmp(pub_key, s_pubkey_hex) != 0) {
                AsyncWebServerResponse *response = request->beginResponse(400, "application/json", "{\"error\":\"Certificate public key does not match this gateway's active public key\"}");
                set_cors_headers(response);
                request->send(response);
                return;
            }

            // Save to NVS
            if (nvs_save_certificate(dev_id, pub_key, sig, issued_at)) {
                AsyncWebServerResponse *response = request->beginResponse(200, "application/json", "{\"status\":\"certificate_installed\"}");
                set_cors_headers(response);
                request->send(response);
            } else {
                AsyncWebServerResponse *response = request->beginResponse(500, "application/json", "{\"error\":\"Failed to save certificate to NVS\"}");
                set_cors_headers(response);
                request->send(response);
            }
        }
    );

    s_server.begin();
    Serial.println("[HTTP] ESPAsyncWebServer started on port 80.");
}
