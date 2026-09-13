/*
  ========================================================================================
  KIWI GATEWAY: Hardware Wi-Fi Safety Companion Access Point
  ========================================================================================
  Target Hardware: ESP32 Dev Module (Official Espressif 'esp32' Arduino Board Package)
  
  REQUIRED ARDUINO LIBRARIES (Install via Sketch > Include Library > Manage Libraries):
  1. "ESPAsyncWebServer" by me-no-dev / lacamera / mathieucarbou (v1.2.3+ or v3.x for ESP32 Core 3.x)
  2. "AsyncTCP" by me-no-dev / mathieucarbou (v1.1.4+ or v3.x for ESP32 Core 3.x)
  3. "ArduinoJson" by Benoit Blanchon (v6.21.x or v7.x supported)
  4. "Crypto" by Rhys Weatherley (rweather) - Provides RFC 8032 Ed25519 cryptography
  5. "U8g2" by oliver (Optional - only required if USE_OLED is set to 1 below)
  
  COMPATIBILITY CAVEATS:
  - ESP32 Core 3.0+: If using Espressif ESP32 Core >=3.0.0, use the modern forks of 
    AsyncTCP and ESPAsyncWebServer (search 'AsyncWebServer_ESP32_ENC' or 'ESPAsyncWebServer' by mathieucarbou)
    to ensure full compatibility with the revamped FreeRTOS network stack.
  - Partition Scheme: Select 'Tools > Partition Scheme > Huge APP (3MB No OTA/1MB SPIFFS)'
    or 'Default 4MB with spiffs' to provide ample space for cryptographic logic and NVS flash.
  ========================================================================================
*/

#include <WiFi.h>
#include <ArduinoJson.h>

#include "crypto_utils.h"
#include "nvs_storage.h"
#include "web_server.h"
#include "oled_display.h"

// Configuration
#define SOFTAP_SSID "KIWI-Secure-Zone"
#define SOFTAP_CHANNEL 1
#define SOFTAP_MAX_CLIENTS 8

// Gateway Runtime State
static char s_device_id[MAX_DEVICE_ID_LEN];
static uint8_t s_gateway_pubkey[ED25519_KEY_SIZE];
static uint8_t s_gateway_privkey[ED25519_KEY_SIZE];
static char s_gateway_pubkey_hex[HEX_STRING_KEY_LEN];

static IPAddress s_local_ip(192, 168, 4, 1);
static IPAddress s_gateway_ip(192, 168, 4, 1);
static IPAddress s_subnet_mask(255, 255, 255, 0);

static unsigned long s_last_display_update = 0;
static String s_serial_command_buffer = "";

void print_banner() {
    Serial.println();
    Serial.println("=================================================================");
    Serial.println("       KIWI: Hardware Wi-Fi Safety Gateway Access Point          ");
    Serial.println("             Ed25519 Cryptographic Trust Anchor                 ");
    Serial.println("=================================================================");
    Serial.printf(" Device ID      : %s\n", s_device_id);
    Serial.printf(" Public Key     : %s\n", s_gateway_pubkey_hex);
    Serial.printf(" Cert Installed : %s\n", nvs_has_certificate() ? "YES (Valid Root CA Signature)" : "NO (Unprovisioned)");
    Serial.printf(" SoftAP SSID    : %s (Open Network)\n", SOFTAP_SSID);
    Serial.printf(" SoftAP IP      : %s\n", WiFi.softAPIP().toString().c_str());
    Serial.println("=================================================================");
    Serial.println(" Type 'HELP' in Serial Monitor for provisioning command list.");
    Serial.println("=================================================================");
}

void print_help() {
    Serial.println("\n--- KIWI Serial Console Commands ---");
    Serial.println(" HELP             : Show this command menu");
    Serial.println(" STATUS           : Show current gateway provisioning & AP state");
    Serial.println(" GET_PUBKEY       : Print the 64-hex-character Ed25519 public key");
    Serial.println(" IMPORT_CERT <json> : Import signed certificate JSON from signing service");
    Serial.println(" REGEN_KEYS       : Generate fresh on-device keypair (invalidates cert)");
    Serial.println(" CLEAR_NVS        : Erase all stored keys and certificates");
    Serial.println(" REBOOT           : Restart ESP32 gateway");
    Serial.println("------------------------------------\n");
}

void process_serial_command(const String& cmd) {
    String trimmed = cmd;
    trimmed.trim();
    if (trimmed.length() == 0) return;

    if (trimmed.equalsIgnoreCase("HELP")) {
        print_help();
    } else if (trimmed.equalsIgnoreCase("STATUS")) {
        print_banner();
    } else if (trimmed.equalsIgnoreCase("GET_PUBKEY")) {
        Serial.printf("\n[PROVISION] Device ID : %s\n", s_device_id);
        Serial.printf("[PROVISION] Public Key: %s\n\n", s_gateway_pubkey_hex);
    } else if (trimmed.startsWith("IMPORT_CERT")) {
        String json_str = trimmed.substring(11);
        json_str.trim();
        if (json_str.length() == 0) {
            Serial.println("[-] Usage: IMPORT_CERT {\"device_id\":\"...\",\"public_key\":\"...\",\"signature\":\"...\",\"issued_at\":12345}");
            return;
        }

        StaticJsonDocument<512> doc;
        DeserializationError err = deserializeJson(doc, json_str);
        if (err) {
            Serial.printf("[-] JSON Deserialization failed: %s\n", err.c_str());
            return;
        }

        const char* dev_id = doc["device_id"];
        const char* pub_key = doc["public_key"];
        const char* sig = doc["signature"];
        uint32_t issued_at = doc["issued_at"] | 0;

        if (!dev_id || !pub_key || !sig || issued_at == 0) {
            Serial.println("[-] Error: Certificate JSON missing required fields.");
            return;
        }

        if (strcasecmp(pub_key, s_gateway_pubkey_hex) != 0) {
            Serial.println("[-] Error: Certificate public key does not match this chip's active keypair!");
            return;
        }

        if (nvs_save_certificate(dev_id, pub_key, sig, issued_at)) {
            Serial.println("[✓] SUCCESS: Signed certificate imported and stored in NVS.");
        } else {
            Serial.println("[-] Error: Failed to commit certificate to NVS.");
        }
    } else if (trimmed.equalsIgnoreCase("REGEN_KEYS")) {
        Serial.println("[!] Regenerating on-device keypair. Prior certificate invalidated.");
        nvs_regenerate_keys(s_device_id, s_gateway_pubkey, s_gateway_privkey, s_gateway_pubkey_hex);
        web_server_update_keys(s_device_id, s_gateway_pubkey, s_gateway_privkey, s_gateway_pubkey_hex);
        print_banner();
    } else if (trimmed.equalsIgnoreCase("CLEAR_NVS")) {
        Serial.println("[!] Clearing NVS flash...");
        nvs_clear_all();
        Serial.println("[✓] NVS wiped. Please reboot.");
    } else if (trimmed.equalsIgnoreCase("REBOOT")) {
        Serial.println("[!] Rebooting ESP32...");
        delay(500);
        ESP.restart();
    } else {
        Serial.printf("[-] Unknown command: '%s'. Type 'HELP' for commands.\n", trimmed.c_str());
    }
}

void setup() {
    // 1. Initialize Serial monitor
    Serial.begin(115200);
    delay(1000);

    // 2. Hardware Cryptographic Subsystem
    crypto_init();

    // 3. Persistent NVS Key Storage
    nvs_init(s_device_id, s_gateway_pubkey, s_gateway_privkey, s_gateway_pubkey_hex);

    // 4. Initialize OLED Display (if enabled)
    display_init();

    // 5. Configure Wi-Fi SoftAP
    WiFi.mode(WIFI_AP);
    WiFi.softAPConfig(s_local_ip, s_gateway_ip, s_subnet_mask);
    WiFi.softAP(SOFTAP_SSID, NULL, SOFTAP_CHANNEL, 0, SOFTAP_MAX_CLIENTS);

    // 6. Initialize Async Web Server & Mutual Auth Endpoints
    web_server_init(s_device_id, s_gateway_pubkey, s_gateway_privkey, s_gateway_pubkey_hex);

    // 7. Output Boot Banner
    print_banner();
}

void loop() {
    // 1. Check for incoming serial commands
    while (Serial.available() > 0) {
        char c = (char)Serial.read();
        if (c == '\r' || c == '\n') {
            if (s_serial_command_buffer.length() > 0) {
                process_serial_command(s_serial_command_buffer);
                s_serial_command_buffer = "";
            }
        } else {
            s_serial_command_buffer += c;
        }
    }

    // 2. Update OLED Display every 1000ms (if enabled)
    if (millis() - s_last_display_update > 1000) {
        s_last_display_update = millis();
        display_update(SOFTAP_SSID,
                       WiFi.softAPIP().toString().c_str(),
                       s_device_id,
                       nvs_has_certificate(),
                       WiFi.softAPgetStationNum());
    }

    delay(10);
}
