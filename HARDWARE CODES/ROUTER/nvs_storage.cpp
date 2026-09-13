#include "nvs_storage.h"
#include <Preferences.h>
#include <esp_system.h>
#if __has_include(<esp_mac.h>)
#include <esp_mac.h>
#endif

static Preferences s_prefs;
static const char* NVS_NAMESPACE = "kiwi_gw";

bool nvs_init(char out_device_id[MAX_DEVICE_ID_LEN],
              uint8_t out_pubkey[ED25519_KEY_SIZE],
              uint8_t out_privkey[ED25519_KEY_SIZE],
              char out_pubkey_hex[HEX_STRING_KEY_LEN]) {
    s_prefs.begin(NVS_NAMESPACE, false);

    bool has_priv = s_prefs.isKey("priv");
    bool has_pub  = s_prefs.isKey("pub");

    if (has_priv && has_pub) {
        size_t priv_read = s_prefs.getBytes("priv", out_privkey, ED25519_KEY_SIZE);
        size_t pub_read  = s_prefs.getBytes("pub", out_pubkey, ED25519_KEY_SIZE);
        String dev_id_str = s_prefs.getString("dev_id", "");

        if (priv_read == ED25519_KEY_SIZE && pub_read == ED25519_KEY_SIZE && dev_id_str.length() > 0) {
            strncpy(out_device_id, dev_id_str.c_str(), MAX_DEVICE_ID_LEN - 1);
            out_device_id[MAX_DEVICE_ID_LEN - 1] = '\0';
            crypto_bytes_to_hex(out_pubkey, ED25519_KEY_SIZE, out_pubkey_hex);
            Serial.printf("[NVS] Loaded existing gateway keys. Device ID: %s\n", out_device_id);
            return true;
        }
    }

    // First boot or corrupted keys: Generate on-device Ed25519 keypair
    Serial.println("[NVS] No valid keypair in NVS. Generating new on-device Ed25519 keypair...");
    return nvs_regenerate_keys(out_device_id, out_pubkey, out_privkey, out_pubkey_hex);
}

bool nvs_regenerate_keys(char out_device_id[MAX_DEVICE_ID_LEN],
                         uint8_t out_pubkey[ED25519_KEY_SIZE],
                         uint8_t out_privkey[ED25519_KEY_SIZE],
                         char out_pubkey_hex[HEX_STRING_KEY_LEN]) {
    // 1. Generate new Ed25519 keypair using hardware RNG
    crypto_generate_keypair(out_pubkey, out_privkey);
    crypto_bytes_to_hex(out_pubkey, ED25519_KEY_SIZE, out_pubkey_hex);

    // 2. Generate unique Device ID based on chip MAC address
    uint8_t mac[6];
    esp_read_mac(mac, ESP_MAC_WIFI_SOFTAP);
    snprintf(out_device_id, MAX_DEVICE_ID_LEN, "KIWI-GW-%02X%02X%02X", mac[3], mac[4], mac[5]);

    // 3. Save to NVS
    s_prefs.putBytes("priv", out_privkey, ED25519_KEY_SIZE);
    s_prefs.putBytes("pub", out_pubkey, ED25519_KEY_SIZE);
    s_prefs.putString("dev_id", out_device_id);
    s_prefs.putBool("has_cert", false); // Key changed, invalidates prior cert

    Serial.printf("[NVS] New keypair stored in NVS. Device ID: %s\n", out_device_id);
    Serial.printf("[NVS] Public Key: %s\n", out_pubkey_hex);
    return true;
}

bool nvs_save_certificate(const char* device_id,
                          const char* public_key_hex,
                          const char* signature_hex,
                          uint32_t issued_at) {
    if (!device_id || !public_key_hex || !signature_hex) return false;

    s_prefs.putString("c_dev", device_id);
    s_prefs.putString("c_pub", public_key_hex);
    s_prefs.putString("c_sig", signature_hex);
    s_prefs.putUInt("c_time", issued_at);
    s_prefs.putBool("has_cert", true);

    Serial.printf("[NVS] Certificate saved for device: %s (issued_at: %u)\n", device_id, issued_at);
    return true;
}

bool nvs_load_certificate(GatewayCertData* cert_out) {
    if (!cert_out) return false;
    if (!s_prefs.getBool("has_cert", false)) {
        cert_out->is_valid = false;
        return false;
    }

    String dev = s_prefs.getString("c_dev", "");
    String pub = s_prefs.getString("c_pub", "");
    String sig = s_prefs.getString("c_sig", "");
    uint32_t issued = s_prefs.getUInt("c_time", 0);

    if (dev.isEmpty() || pub.isEmpty() || sig.isEmpty()) {
        cert_out->is_valid = false;
        return false;
    }

    memset(cert_out, 0, sizeof(GatewayCertData));
    strncpy(cert_out->device_id, dev.c_str(), sizeof(cert_out->device_id) - 1);
    cert_out->device_id[sizeof(cert_out->device_id) - 1] = '\0';

    strncpy(cert_out->public_key_hex, pub.c_str(), sizeof(cert_out->public_key_hex) - 1);
    cert_out->public_key_hex[sizeof(cert_out->public_key_hex) - 1] = '\0';

    strncpy(cert_out->signature_hex, sig.c_str(), sizeof(cert_out->signature_hex) - 1);
    cert_out->signature_hex[sizeof(cert_out->signature_hex) - 1] = '\0';

    cert_out->issued_at = issued;
    cert_out->is_valid = true;

    return true;
}

bool nvs_has_certificate() {
    return s_prefs.getBool("has_cert", false);
}

void nvs_clear_all() {
    s_prefs.clear();
    Serial.println("[NVS] All preferences cleared.");
}
