# KIWI Mobile: Wi-Fi Safety Companion App

A cross-platform Flutter application (Dart SDK >=3.0.0) implementing **KIWI's client-side mutual authentication engine** to protect users connecting to open Wi-Fi gateways from rogue access points and "Evil Twin" attacks.

---

## 1. Overview & Security Architecture

When a phone associates with an open Wi-Fi hotspot (such as `KIWI-Secure-Zone`), it runs an automated **two-directional, 4-layer cryptographic handshake** before any sensitive network traffic is allowed through:

```
[Phone App]                                          [ESP32 Gateway: 192.168.4.1]
    │                                                              │
    │─── 1. POST /api/v1/mutual_auth {client_nonce: 32B} ─────────>│
    │                                                              │ 2. Signs client_nonce
    │<── 3. {signature, certificate, router_nonce: 32B} ───────────│
    │
    │─── 4. Evaluates 4 Verification Layers:
    │       Layer 1: Gateway Certificate validated against Root CA public key
    │       Layer 2: Challenge signature validated against Certified Gateway key
    │       Layer 3: Nonce match & issuance timestamp freshness (anti-replay)
    │       Layer 4: Device ID checked against local Revocation List (CRL)
    │       * Any failure -> Hostile "KIWI Iron Gate" State + Threat Logged *
    │
    │─── 5. POST /api/v1/client_verify {signature, router_nonce} ──>│
    │                                                              │ 6. Enforces single-use TTL
    │<── 7. HTTP 200 { status: "authorized" } ─────────────────────│
    │
    ▼
SHIELD ACTIVE / VERIFIED (Safe Connection Established)
```

---

## 2. Key Security Properties

### A. Hardware-Backed Keypair Storage
- On first launch, the mobile app generates an RFC 8032 Ed25519 keypair.
- The private key seed is stored **strictly in hardware-backed secure storage** via `flutter_secure_storage` (Android Keystore with EncryptedSharedPreferences / iOS Keychain with `first_unlock` accessibility).
- It is **never** committed, written to `SharedPreferences`, or transmitted over the network.

### B. Safe Embedded Root CA Public Key
- The authoritative KIWI Root CA public key is safely hardcoded into `lib/constants/security_constants.dart`.
- The corresponding Root CA private key remains completely offline in `../provisioning/vault/`.

### C. Persistent Threat Audit Trail & Bypass Tracking
- When an untrusted, rogue, or replayed gateway fails any verification layer, an incident record is immediately appended to the local threat log (`SharedPreferences`).
- If an advanced user selects **"Connect Anyway (At Your Own Risk)"** from the expandable **Advanced Security Bypass** drawer, the threat log entry is **preserved** and updated with `bypassed: true` for forensic auditing.

### D. Offline Revocation List (CRL) Caching
- When offline or on a captive portal network, the app validates gateway Device IDs against a locally cached CRL.
- If the cache exceeds 7 days, an amber staleness indicator alerts the user while still enforcing Layers 1, 2, and 3.

---

## 3. UI Design System & Screens

Designed with a sleek **Material 3 Dark Theme**:
- **Base Background**: `#0F172A` (Deep Slate)
- **Surface Cards**: `#1E293B`
- **Accent**: `#14B8A6` (Teal)
- **Verified State**: `#064E3B` / `#10B981` (Emerald)
- **Hostile ("Iron Gate") State**: `#7F1D1D` / `#EF4444` (Crimson)
- **Challenging State**: `#1E3A8A` / `#3B82F6` (Deep Navy)

### Screen Directory:
- **`scanner_screen.dart`**: Discovers nearby open Wi-Fi APs with signal strength (`dBm`) and "Unverified" badges. Includes a direct IP input for connecting to physical ESP32 gateways (`192.168.4.1`) plus an interactive **Threat Simulation Matrix** for testing all 4 failure layers without hardware.
- **`status_screen.dart`**: The dynamic verification interface displaying:
  1. *Challenging*: Navy card with animated pulsing radar and SLA countdown.
  2. *Verified ("Shield Active")*: Emerald card, shield icon, latency in ms, certified Device ID, and "Connect Safely" button.
  3. *Hostile ("KIWI Iron Gate")*: Crimson warning card, failure layer breakdown, auto-logged confirmation badge, and expandable "Advanced Security Bypass" drawer.
- **`threat_log_screen.dart`**: Forensic audit log displaying recorded rogue access points, BSSID, timestamp, specific failed layers, user bypass tags, and a purge action.

---

## 4. Dependencies

| Package | Purpose |
| :--- | :--- |
| `cryptography` | High-performance RFC 8032 Ed25519 signing and verification |
| `flutter_secure_storage` | Hardware-backed keypair storage (Android Keystore / iOS Keychain) |
| `http` | REST client enforcing strict 2000ms SLA handshake timeouts |
| `wifi_scan` | Discovers nearby unencrypted wireless access points |
| `network_info_plus` | Inspects currently connected Wi-Fi network metadata |
| `shared_preferences` | Persists forensic threat audit logs and cached CRL entries |
| `intl` | Formats forensic timestamps in threat logs |

---

## 5. Development & Testing

### Static Code Analysis
Run code analysis to ensure 0 linter errors and 0 warnings:
```bash
flutter analyze
```

### Run Unit & Widget Test Suite
Run the 8 automated tests covering Ed25519 cryptography, cross-platform Root CA signature validation, CRL matching, and threat log bypass persistence:
```bash
flutter test
```

### Launch App
```bash
# In an Android/iOS emulator or on a connected physical device:
flutter run
```
