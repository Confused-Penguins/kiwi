# KIWI: Your Wi-Fi Safety Companion

> **Zero-Trust Verification Against Rogue Access Points & "Evil Twins"**  
> Cryptographically authenticate open Wi-Fi gateways on first contact with zero prior setup using an asymmetric Ed25519 Certificate Authority (CA) trust model.

---

## 1. System Overview & Problem Statement

Public and open Wi-Fi networks (airports, hotels, cafes) are fundamentally vulnerable to **"Evil Twin"** attacks: an adversary creates a spoofed access point broadcasting the identical SSID and BSSID as a legitimate hotspot. When victim devices connect, the adversary intercepts DNS requests, injects malicious captive portals, and harvests credentials.

Traditional enterprise solutions (WPA3-Enterprise 802.1X, RADIUS) require complex configuration profiles and pre-shared user credentials impossible for ad-hoc public environments.

**KIWI solves this on first contact with zero prior setup**:
1. A single authoritative **KIWI Root Ed25519 Keypair** acts as a lightweight Certificate Authority (CA).
2. The **Root Public Key** is safely hardcoded into the mobile application. The Root Private Key is kept strictly offline.
3. Every genuine ESP32 gateway generates its own Ed25519 keypair on-device in hardware/NVS and receives a signed certificate from the Root CA.
4. When a phone associates with the gateway, it conducts an automated **two-directional, 4-layer mutual cryptographic challenge** within a strict 2000ms window before sensitive network traffic is permitted.

---

## 2. Cryptographic Trust Model & Handshake Protocol

```
PHONE CLIENT                                    ESP32 GATEWAY (192.168.4.1)
  │                                                        │
  │─── 1. POST /api/v1/mutual_auth {client_nonce} ────────>│
  │                                                        │ 2. Signs client_nonce
  │                                                        │    Generates router_nonce
  │<── 3. {signature, certificate, router_nonce} ──────────│
  │
  │─── 4. Phone Evaluates 4 Verification Layers:
  │       [Layer 1] Validate Certificate against Root CA Public Key
  │       [Layer 2] Validate Signature against Certified Gateway Key
  │       [Layer 3] Freshness check (client_nonce match, timestamp)
  │       [Layer 4] Local Revocation List (CRL) check (Device ID)
  │       *Any failure -> "KIWI Iron Gate" Hostile State + Threat Log
  │
  │─── 5. POST /api/v1/client_verify {signature, nonce} ──>│
  │                                                        │ 6. Validates router_nonce
  │                                                        │    Checks single-use TTL
  │                                                        │    Verifies phone sig
  │<── 7. HTTP 200 { status: "authorized" } ───────────────│
  │
  ▼
SHIELD ACTIVE / VERIFIED (Safe Connection Established)
```

### The 4 Verification Layers (Direction 1)
- **Layer 1 (Root CA Binding)**: Reconstructs canonical payload `KIWI-CERT:v1:<device_id>:<public_key_hex>:<issued_at>` and verifies the signature using the hardcoded KIWI Root CA public key.
- **Layer 2 (Challenge-Response Proof-of-Possession)**: Verifies the gateway holds the private key matching the certified public key by validating the signature of `KIWI-AUTH:v1:<client_nonce_hex>`.
- **Layer 3 (Freshness & Anti-Replay)**: Enforces that the gateway signed the freshly generated 32-byte nonce (not a replayed signature) and validates that certificate `issued_at` is temporally sane.
- **Layer 4 (Authoritative Revocation)**: Confirms `device_id` is not listed in the locally cached Certificate Revocation List (CRL).

### Gateway Client Verification (Direction 2)
The phone signs the gateway's 32-byte `router_nonce` using its own Ed25519 private key (stored in Android Keystore / iOS Keychain via `flutter_secure_storage`). The gateway validates the signature and ensures the nonce is single-use with a 30-second TTL.

---

## 3. Security Tradeoffs & Architectural Decisions

### A. Revocation List (CRL) Staleness When Offline
* **The Challenge**: When a mobile device first connects to a captive or untrusted gateway, it has no WAN/Internet connectivity to query a live OCSP server or download an updated CRL.
* **Our Tradeoff & Mitigation**:
  1. **Locally Cached CRL with Timestamp**: The app persists the most recent CRL fetched during normal internet usage.
  2. **Staleness Grace Period**: The app verifies device IDs against the cached list. If the cache is older than 7 days, an amber warning banner is displayed while still enforcing Layers 1, 2, and 3.
  3. **Time-Bounded Certificates**: Gateway certificates include an `issued_at` timestamp. In production, certificates expire within 30 to 90 days, limiting the window of vulnerability if a compromised gateway is revoked.

### B. Hardware Key Isolation & NVS on ESP32
* **On-Device Key Generation**: Keys are generated directly on the ESP32 using hardware entropy (`esp_random()`). The private key never leaves the chip.
* **Production vs Development Flash Encryption**:
  - In production, ESP32 hardware **Flash Encryption (eFuse)** and **Secure Boot** must be burned so the NVS partition is encrypted by the chip's internal AES-XTS engine.
  - In development mode without burned eFuses, NVS is protected by chip partition boundaries, and keys can be securely wiped using the serial command `CLEAR_NVS`.

### C. Zero-Heap Crypto Guarantees
All cryptographic operations in the ESP32 firmware use fixed static buffers (`uint8_t[32]`, `uint8_t[64]`). No heap memory (`malloc`, `new`, or dynamic `String` buffers) is allocated in the signature or verification pathways, preventing memory fragmentation and heap-based denial of service.

### D. Threat Logging Independence
If a user deliberately triggers the **"Advanced Security Bypass"** on a hostile network, KIWI records the incident in the local forensic Threat Audit Log *before* allowing the bypass, preserving tamper-resistant incident history.

---

## 4. Monorepo Structure

```
kiwi/
├── README.md                     # Monorepo architecture & security specs
├── provisioning/                 # Offline Root CA & Provisioning Toolchain (Python 3)
│   ├── generate_root_key.py      # Generates Root CA Ed25519 keypair into secure vault
│   ├── sign_gateway_cert.py      # Signs gateway public keys with Root CA private key
│   ├── manage_revocation.py      # CLI tool to add/remove/list revoked gateway IDs
│   ├── verify_cert.py            # Standalone certificate verification utility
│   ├── test_provisioning_flow.py # End-to-end automated test suite
│   ├── revocation_list.json      # Starter Certificate Revocation List (CRL)
│   ├── requirements.txt          # Python dependencies (cryptography>=41.0.0)
│   └── vault/                    # Secure local vault (0600 file permissions, excluded from commits)
│       ├── root_private_key.json # SENSITIVE: Root CA private key
│       └── root_public_key.hex   # Authoritative Root CA public key
├── firmware/                     # Arduino IDE Gateway Sketch (NOT PlatformIO)
│   ├── README.md                 # Setup guide, library manager names, flashing steps
│   └── kiwi_gateway/             # Standard Arduino IDE sketch directory
│       ├── kiwi_gateway.ino      # Main sketch entry point & serial CLI processor
│       ├── crypto_utils.h/.cpp   # Ed25519 zero-heap operations via rweather/Crypto
│       ├── nvs_storage.h/.cpp    # Preferences NVS flash key & certificate storage
│       ├── web_server.h/.cpp     # ESPAsyncWebServer mutual auth & CORS routes
│       └── oled_display.h/.cpp   # Optional SSD1306 OLED status display (USE_OLED)
└── mobile/                       # Flutter Mobile Companion App (Dart SDK >=3.0.0)
    ├── pubspec.yaml              # Dependencies (cryptography, flutter_secure_storage, etc.)
    ├── android/                  # Android configuration with cleartext traffic enabled
    ├── lib/
    │   ├── main.dart             # App bootstrap & service dependency injection
    │   ├── constants/            # Root CA public key constant & protocol definitions
    │   ├── models/               # Data structures & verification layer representations
    │   ├── services/
    │   │   ├── crypto_service.dart  # 4-layer validation & RFC 8032 signing
    │   │   ├── storage_service.dart # Keystore/Keychain secure key & threat log storage
    │   │   └── network_service.dart # 2000ms SLA mutual handshake orchestrator
    │   ├── theme/                # Material 3 Dark theme (#0F172A base, #14B8A6 teal)
    │   └── screens/
    │       ├── scanner_screen.dart    # Live AP scanner & demo test matrix
    │       ├── status_screen.dart     # Challenging / Verified / Iron Gate states
    │       └── threat_log_screen.dart # Forensic threat audit log & bypass tracker
    └── test/                     # Unit test suites (crypto, 4-layer checks, threat log)
```

---

## 5. Quickstart & Verification

### 1. Test Provisioning Toolchain
```bash
cd kiwi/provisioning
python3 test_provisioning_flow.py
```

### 2. Verify Flutter Mobile App
```bash
cd kiwi/mobile
flutter pub get
flutter analyze
flutter test
```

### 3. Flash & Provision ESP32 Gateway
1. Open `kiwi/firmware/kiwi_gateway/kiwi_gateway.ino` in Arduino IDE.
2. Install required libraries: `Crypto` (rweather), `ArduinoJson`, `ESPAsyncWebServer`, `AsyncTCP`.
3. Select Board: `ESP32 Dev Module`, Partition: `Huge APP (3MB)`.
4. Upload to ESP32 and open Serial Monitor at `115200` baud.
5. Follow the step-by-step provisioning guide in `firmware/README.md`.
