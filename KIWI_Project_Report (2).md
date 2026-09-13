# KIWI: Wi-Fi Safety Companion
## Full Project Report

---

## 1. Problem Statement

Open, unencrypted Wi-Fi networks (cafes, airports, hotels, campuses) are trivially spoofable. Anyone can stand up a rogue access point broadcasting the same SSID as a legitimate one — an "evil twin" attack — and intercept, redirect, or tamper with traffic from unsuspecting users who connect based on the network name alone.

There is currently no lightweight, user-facing way to answer: **"Is this specific access point the trusted hardware I think it is, or an impersonator?"** SSID names, signal strength, and open/locked padlock icons offer no cryptographic guarantee of identity.

## 2. Solution Summary

KIWI turns physical gateway hardware into a cryptographically verifiable trust anchor. A phone running the KIWI app can walk up to **any** KIWI-provisioned gateway — one it has never seen before — and cryptographically confirm it is a legitimate, KIWI-issued device before connecting, using a **mutual challenge-response handshake** built on **Ed25519 (RFC 8032)** digital signatures.

This is the same trust model that secures HTTPS on the web (a certificate authority vouching for otherwise-unknown servers), applied to a physical local-network context instead of a domain name.

## 3. What Is Being Built

| Component | Role |
|---|---|
| **ESP32 Gateway** | Runs as the trusted access point. Proves its identity to any connecting phone via certificate + live signature. |
| **Flutter Mobile App ("KIWI")** | Scans nearby open Wi-Fi, runs the verification handshake, shows a clear verdict, and logs threats locally. |
| **KIWI Signing Service (backend)** | Issues certificates to gateways at deployment time and maintains a revocation list. |
| **Key/Cert Provisioning Tooling** | One-time scripts run per-gateway at manufacture/deployment to generate keys and request a signed certificate. |

## 4. Trust Model: Why a Certificate Authority, Not Shared Keys

### The problem with the original static-key design
An early design embedded one shared keypair directly into all firmware and all app builds. This fails the actual use case (a stranger connecting to an unfamiliar gateway with zero prior setup) for two reasons:
- It only works if the phone and that *one specific* gateway were paired in advance — incompatible with "walk up to any random public Wi-Fi."
- A single extracted key (from a decompiled APK or dumped firmware) compromises every device system-wide, since the key is shared across all units.

### The fix: passport / border-control model
- **KIWI (root authority)** generates one master signing keypair once. The private half is kept in a secure signing environment and never touches an end-user device. The public half is safe to embed directly in the app — it is meant to be public, exactly like a browser's built-in root CA list.
- **Each ESP32 gateway** generates its **own unique keypair on-device** at deployment. Its private key never leaves the chip (stored in encrypted flash / eFuse-backed NVS). Only its public key is sent to the KIWI signing service, which returns a signed **certificate**: proof that "KIWI vouches this specific public key belongs to a legitimate device."
- **Each phone install** generates its **own keypair** on first launch, stored in the OS-level secure enclave (Android Keystore / iOS Keychain), not in plaintext app storage.

This means a stranger's phone can verify a stranger's gateway on first contact, without any prior relationship — the phone only needs to trust the one root public key it shipped with.

## 5. The Two-Directional Verification Protocol

The handshake checks identity in **both directions**:

**Direction 1 — Phone verifies the Gateway (the safety-critical check):**
1. Phone generates a random nonce, sends it to the gateway.
2. Gateway signs the nonce with its private key, returns the signature plus its KIWI-issued certificate.
3. Phone checks the certificate against KIWI's root public key, then checks the signature against the certificate's public key.
4. Failure at either step → **Iron Gate** hostile state; incident logged.

**Direction 2 — Gateway verifies the Phone (integrity / anti-abuse check):**
5. Gateway sends its own nonce back.
6. Phone signs it with its own key and returns the signature.
7. Gateway checks the signature is valid and fresh (not a replay).
8. Failure → gateway returns `403 rejected`.

Only when both directions succeed does the app show the **Verified / Shield Active** state. Note: Direction 2 does not require a pre-approved, specific phone identity (any legitimate KIWI app install is acceptable) — it exists mainly to prevent replay/garbage traffic from spoofing a "verified" result on the gateway side.

## 6. Four-Layer Verification Model

| Layer | Question it answers | Attack it blocks |
|---|---|---|
| 1. Certificate check | Was this device ever legitimately issued a KIWI identity? | Fully fabricated, unrelated fake gateways |
| 2. Challenge-response | Does it hold the matching private key *right now*? | Copied/cloned certificates without the real key |
| 3. Freshness / anti-replay | Is this a new nonce, not a recorded one? | Replayed, previously-captured handshakes |
| 4. Revocation check | Has this device been reported lost or compromised? | Genuinely stolen/extracted private keys |

A fake gateway must pass all four; failing any single layer routes the user to the hostile state.

## 7. Full Technical Stack

### Firmware (ESP32 Gateway)
- **Language / framework**: C++ on Arduino framework, built and flashed via **Arduino IDE** (Board: "ESP32 Dev Module" or the specific board variant, via the `esp32` board package by Espressif installed through Boards Manager)
- **Sketch layout**: a single `.ino` sketch (e.g. `kiwi_gateway.ino`) plus supporting `.h`/`.cpp` tabs in the same sketch folder (Arduino IDE compiles all files in the sketch directory together — no build config file needed)
- **Libraries**: installed via Arduino IDE's **Library Manager** (Sketch → Include Library → Manage Libraries), not a package manifest:
  - `ESPAsyncWebServer` (by mathieucarbou or the ESP32Async fork — check compatibility with your installed `esp32` core version)
  - `AsyncTCP`
  - `ArduinoJson`
  - `Crypto` (by rweather) for Ed25519 sign/verify
  - `U8g2` (optional, only if using the OLED status display)
- **Networking**: SoftAP mode at `192.168.4.1`, served by `ESPAsyncWebServer` + `AsyncTCP`
- **Crypto**: `rweather/Crypto` (Ed25519 sign/verify); `esp_random()` as nonce entropy source
- **Key storage**: on-device keypair generation; private key in encrypted NVS via the `Preferences` or `nvs_flash` API (enable flash encryption in Arduino IDE's Tools menu if targeting production-grade key protection) — never in source
- **Memory model**: static/global buffers only in crypto paths (no heap allocation)
- **Optional**: OLED status display via `U8g2`, feature-flagged with `#if USE_OLED` at the top of the sketch

### Mobile App (Flutter)
- **Framework**: Flutter, Dart SDK ≥3.0.0
- **Crypto**: `cryptography` package (Ed25519), `Random.secure()` for nonces
- **Secure key storage**: `flutter_secure_storage` (Android Keystore / iOS Keychain) — not plaintext constants
- **Networking**: `http`, strict 2000ms per-request timeout
- **Wi-Fi scanning**: `wifi_scan` + `network_info_plus`, filtered to open/unencrypted APs
- **Local persistence**: `shared_preferences` for the threat log
- **Formatting**: `intl`
- **UI**: Material 3, dark theme (`#0F172A` base, `#14B8A6` teal accent)
  - Scanner screen (AP list, RSSI, "Unverified" badges)
  - Status screen — Challenging (navy, pulsing radar), Verified (emerald `#064E3B`, shield icon), Hostile (crimson `#7F1D1D`, "Iron Gate", bypass option)
  - Threat log screen (rogue-AP audit trail)
- **Android config**: cleartext HTTP permitted (plain-HTTP local AP, no cert infra at the network layer itself); Wi-Fi/location permissions for scanning

### KIWI Signing Service (backend — new)
- Small service holding the root private key (ideally in an HSM or secrets manager)
- Endpoint: accepts a gateway's public key + device ID, returns a signed certificate
- Endpoint: serves a revocation list the app can periodically check
- Can be minimal — a script or small API; not part of the real-time verification path

### Key/Cert Provisioning Tooling
- Python 3 (`cryptography` package) for the one-time root-key generation and any offline signing tooling
- Per-device provisioning step run once at gateway setup: on-device keygen → certificate signing request → signed cert written back to device flash

## 8. Known Limitations / Residual Risks

- **Root key custody**: the security of the entire system depends on protecting the KIWI root private key. Compromise of that one key would let an attacker mint valid-looking certificates for fake gateways.
- **Revocation freshness**: if the phone can't reach the revocation list (offline), it falls back to certificate + live challenge only — still blocks cloning, but not "this exact device was reported stolen ten minutes ago."
- **No traffic encryption**: the handshake protects against *impersonation*, not *eavesdropping* — data after connecting still travels over plain HTTP/open Wi-Fi unless a separate encryption layer is added.
- **User bypass option**: the "Connect Anyway" friction gate is intentional for usability, but should always still log the incident regardless of user choice.

## 9. Verification / Testing Plan

- Standalone Python script simulating the full handshake (cert issuance → challenge-response → verify) to confirm cross-compatibility between firmware-side and app-side crypto before any hardware is involved.
- `flutter analyze` / `dart analyze` for static correctness on the mobile side.
- Manual review of firmware crypto calls against the `rweather/Crypto` Ed25519 API.
- Manual review of certificate issuance flow and revocation list handling.
- UI/UX pass on all three status states and the threat log.

---

*End of report.*
