# KIWI Gateway Firmware (ESP32)

Arduino IDE project implementing the **KIWI Hardware Wi-Fi Gateway**. The gateway hosts a verified open SoftAP (`KIWI-Secure-Zone`), performs RFC 8032 Ed25519 mutual challenge-response authentication, manages on-chip cryptographic keys in NVS, and features zero-heap crypto operations to prevent memory fragmentation.

---

## 1. Required Arduino Libraries

Open **Arduino IDE** and navigate to:
`Sketch > Include Library > Manage Libraries...`

Install the following libraries by their exact Library Manager names:

| Library Name | Author | Recommended Version | Purpose |
| :--- | :--- | :--- | :--- |
| **`Crypto`** | Rhys Weatherley (`rweather`) | `0.4.0` or latest | RFC 8032 Ed25519 signature & verification |
| **`ArduinoJson`** | Benoît Blanchon | `6.21.x` or `7.x` | High-performance JSON serialization |
| **`ESPAsyncWebServer`** | `mathieucarbou` or `me-no-dev` | `v1.2.3` / `v3.1.x` | Non-blocking asynchronous REST API |
| **`AsyncTCP`** | `mathieucarbou` or `me-no-dev` | `v1.1.4` / `v3.1.x` | Asynchronous TCP foundation |
| **`U8g2`** *(Optional)* | Oliver | `2.35.x` | Only required if `#define USE_OLED 1` is enabled |

### Core Compatibility Caveat
- **ESP32 Core 3.0+ Notice**: If your Arduino IDE uses the modern Espressif `esp32` board package version `3.0.0` or higher, install the maintained forks of `ESPAsyncWebServer` and `AsyncTCP` by **Mathieu Carbou** (`mathieucarbou`). The legacy `me-no-dev` repository was designed for ESP32 Core 2.0.x and may cause compilation errors with the new FreeRTOS networking API in Core 3.x.

---

## 2. Arduino IDE Board & Tools Configuration

In the Arduino IDE menu, configure:

- **Board**: `Tools > Board > esp32 > ESP32 Dev Module`
- **Upload Speed**: `Tools > Upload Speed > 921600` (or `115200` if cable is unstable)
- **CPU Frequency**: `Tools > CPU Frequency > 240MHz (WiFi/BT)`
- **Flash Frequency**: `Tools > Flash Frequency > 80MHz`
- **Flash Mode**: `Tools > Flash Mode > QIO`
- **Partition Scheme**: `Tools > Partition Scheme > Huge APP (3MB No OTA/1MB SPIFFS)` or `Default 4MB with spiffs`
  *(Ensures ample Flash capacity for cryptographic libraries and persistent NVS storage)*
- **Port**: Select the USB Serial COM port corresponding to your ESP32 board (e.g. `/dev/cu.usbserial-...` on macOS or `COMx` on Windows).

---

## 3. Step-by-Step Flashing & Provisioning Guide

### Step A: Flashing the Sketch
1. Open Arduino IDE.
2. Select `File > Open...` and choose `kiwi/firmware/kiwi_gateway/kiwi_gateway.ino`.
3. Verify that all supporting tabs (`crypto_utils.h`, `crypto_utils.cpp`, `nvs_storage.h`, `nvs_storage.cpp`, `web_server.h`, `web_server.cpp`, `oled_display.h`, `oled_display.cpp`) appear automatically in the Arduino IDE editor tabs.
4. Click **Verify / Compile** (check mark icon) to ensure zero errors.
5. Connect your ESP32 via USB and click **Upload** (arrow icon).
6. Open **Tools > Serial Monitor** and set baud rate to `115200`.

### Step B: Provisioning Gateway Keypair & Certificate
1. On initial boot, the ESP32 generates an Ed25519 keypair using hardware entropy (`esp_random()`) and assigns a unique Device ID:
   ```text
   =================================================================
          KIWI: Hardware Wi-Fi Safety Gateway Access Point          
                Ed25519 Cryptographic Trust Anchor                 
   =================================================================
    Device ID      : KIWI-GW-A1B2C3
    Public Key     : 8a4c21...64-chars
    Cert Installed : NO (Unprovisioned)
    SoftAP SSID    : KIWI-Secure-Zone (Open Network)
    SoftAP IP      : 192.168.4.1
   =================================================================
   ```
2. Retrieve the public key by typing `GET_PUBKEY` in the Serial Monitor, or send a `GET` request to:
   ```bash
   curl http://192.168.4.1/api/v1/provision/status
   ```
3. Sign the gateway's public key with your offline KIWI Root CA:
   ```bash
   cd kiwi/provisioning
   python3 sign_gateway_cert.py \
       --device-id KIWI-GW-A1B2C3 \
       --gateway-pubkey 8a4c21...64-chars \
       --output cert.json
   ```
4. Import the signed certificate into the ESP32:
   - **Via Serial Monitor**:
     ```text
     IMPORT_CERT {"device_id":"KIWI-GW-A1B2C3","public_key":"8a4c21...","signature":"5f2e...","issued_at":1726123456}
     ```
   - **Or via HTTP API**:
     ```bash
     curl -X POST http://192.168.4.1/api/v1/provision/cert \
          -H "Content-Type: application/json" \
          -d @cert.json
     ```
5. Confirm provisioning: Type `STATUS` in Serial Monitor. You will see:
   `Cert Installed : YES (Valid Root CA Signature)`.

---

## 4. Manual Hardware Verification Checklist

- [ ] Connect ESP32 Dev Module via USB.
- [ ] Select Board: `ESP32 Dev Module`, Partition: `Huge APP (3MB)`.
- [ ] Verify Libraries: `Crypto` (rweather), `ArduinoJson`, `ESPAsyncWebServer`, `AsyncTCP`.
- [ ] Compile sketch (verify clean build).
- [ ] Upload to ESP32 board.
- [ ] Open Serial Monitor at `115200` baud.
- [ ] Confirm boot logs display `KIWI-Secure-Zone` SoftAP active at `192.168.4.1`.
- [ ] Connect a device to Wi-Fi SSID `KIWI-Secure-Zone` without password.
- [ ] Run `GET http://192.168.4.1/api/v1/provision/status` to test web server.
