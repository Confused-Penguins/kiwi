# Kiwi 🥝 — UI/UX Design System & Specification

This folder contains the complete, pixel-perfect **UI/UX Design System** for **Kiwi: Hardware-Verified Wi-Fi Trust Anchor**.

---

## 🎨 Design System Overview (*"Technological Minimalism"*)

- **Visual Style:** Minimalist tactical glassmorphism on a warm silver-gray canvas.
- **Background Canvas:** `#BDC2BE` / `#BAC0B9` (Warm muted silver-gray).
- **Cards & Surfaces:** `#FFFFFF` (Pure white rounded cards, `rounded-3xl` / 20px radius).
- **Primary Typography:** `#151719` / `#111827` (Dark charcoal bold sans-serif).
- **Accents & Status:**
  - 🟢 **Verified / Secured:** `#8CE2A8` (Soft Mint Green badge) & `#10B981` (Emerald).
  - 🔴 **Hostile / Evil Twin Blocked:** `#FECDD3` (Rose Red container) & `#EF4444` (Crimson Alert).
  - 🔵 **Telemetry / Location:** `#0284C7` (Ice Blue).

---

## 📱 Local Code Design Files (HTML5 / Tailwind CSS)

- **[`dashboard.html`](file:///c:/Users/hp/Desktop/Kiwi/designs/dashboard.html)**: Standalone 1:1 mobile dashboard matching [`dashboard.jpeg`](file:///c:/Users/hp/Desktop/Kiwi/dashboard.jpeg).
- **[`location_screen.html`](file:///c:/Users/hp/Desktop/Kiwi/designs/location_screen.html)**: Auto-detected GPS location + manual input fallback screen.
- **[`scan_screen.html`](file:///c:/Users/hp/Desktop/Kiwi/designs/scan_screen.html)**: Radar pulse Wi-Fi scanner and trust verification interface.
- **[`verified_screen.html`](file:///c:/Users/hp/Desktop/Kiwi/designs/verified_screen.html)**: Green verified state with Ed25519 cryptographic proof details.
- **[`hostile_screen.html`](file:///c:/Users/hp/Desktop/Kiwi/designs/hostile_screen.html)**: Red hostile state ("Iron Gate" Evil Twin attack lockdown screen).

---

## ☁️ Stitch Cloud Project & Screen IDs

All UI screens are stored and editable in your **Stitch** project (**`Kiwi Mobile App`**, Project ID: `6395553925780947525`):

| Screen | Stitch Screen ID | Description |
| :--- | :--- | :--- |
| **Mobile Dashboard (1:1 Replica)** | `d79b13637ff646a0b6afd37a98dbb716` | Exact match to `dashboard.jpeg` with Kiwi bird logo, headline greeting, 2x2 grid (`Kiwi Scan`, `Connection Status`, `Saved anchors`, `Location`), search bar, lower-right watermark, floating dock & `+` button. |
| **Location Detection** | `80e28cca001c41ba990fb40b48a7c674` | Auto-detected location (*VIT University, Vellore*), compass radar graphic, and **"Enter Location Manually"** fallback button & dialog. |
| **Scan / Verification** | `b114080984114bd9a6559e69f788c0f6` | Central Wi-Fi orb radar pulse visual with single **"Verify Network"** CTA. |
| **Verified State (Green UI)** | `47cc9e4dffe547bea3c3b284b26deb40` | *"Connection Verified"*, *"Hardware Trust Anchor Confirmed"*, and Ed25519 cryptographic proof card. |
| **Hostile State (Red UI)** | `4f6e789a085b4bf6a2c75e5d7160c4ac` | *"Connection Blocked: Evil Twin Detected"*, threat breakdown card, and collapsible risk bypass tile. |

---

## 📂 Asset References

- **[`dashboard.jpeg`](file:///c:/Users/hp/Desktop/Kiwi/dashboard.jpeg)**: Original reference mockup image.
- **[`logokiwi.jpeg`](file:///c:/Users/hp/Desktop/Kiwi/logokiwi.jpeg)**: Official Kiwi logo icon asset.
