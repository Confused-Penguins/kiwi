/*
  KIWI Sentinel — Sniffer, OLED, Buzzer & LED (Dedicated Node)
  =============================================================
  No AP broadcast. No web portal. 
  Fixed fonts to eliminate clipping, active hardware indicators, 
  and ESP-NOW link to Companion.
*/

#include <WiFi.h>
#include <esp_wifi.h>
#include <esp_now.h>
#include <U8g2lib.h>
#include <Wire.h>

extern "C" {
  #include "esp_wifi_types.h"
}

// ---- Hardware Pins --------------------------------------------------------
#define OLED_SDA_PIN 8
#define OLED_SCL_PIN 9
#define BUZZER_PIN   10
#define LED_PIN      7

U8G2_SSD1306_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, U8X8_PIN_NONE);

// ---- Hardcoded Network & Channel -----------------------------------------
const char* TARGET_SSID  = "KIWI-Secure-Zone";
uint8_t TARGET_MAC[6]    = {0x8C, 0x4F, 0x00, 0x29, 0x60, 0x35};
uint8_t COMPANION_MAC[6] = {0xA0, 0xF2, 0x62, 0xA6, 0x77, 0x1C};
int TARGET_CHANNEL       = 1;

// ---- State ----------------------------------------------------------------
struct AttackEvent {
  unsigned long uptimeSeconds;
  uint8_t sourceMac[6];
  uint8_t reasonCode;
  int8_t rssi;
  bool isDeauth;
};

unsigned long lastAttackUptime = 0;
unsigned long totalAttacksThisSession = 0;
portMUX_TYPE eventMux = portMUX_INITIALIZER_UNLOCKED;

volatile bool pendingEspNowEvent = false;
AttackEvent pendingEventCopy;

typedef struct __attribute__((packed)) {
  uint8_t msgType;              // 0 = Heartbeat, 1 = Attack Event
  unsigned long uptimeSeconds;  
  uint8_t sourceMac[6];         
  uint8_t reasonCode;           
  int8_t rssi;                  
  uint8_t isDeauth;             
  unsigned long totalAttacks;   
  uint8_t targetMac[6];         
  uint16_t channel;             
} SentinelMessage;

unsigned long lastHeartbeatMs = 0;
unsigned long lastOledUpdate  = 0;

// ---- Helpers ------------------------------------------------------------
bool macEquals(const uint8_t* a, const uint8_t* b) {
  for (int i = 0; i < 6; i++) if (a[i] != b[i]) return false;
  return true;
}

String macToString(const uint8_t* mac) {
  char buf[18];
  snprintf(buf, sizeof(buf), "%02X:%02X:%02X:%02X:%02X:%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  return String(buf);
}

void addEvent(const uint8_t* sourceMac, uint8_t reasonCode, int8_t rssi, bool isDeauth) {
  portENTER_CRITICAL_ISR(&eventMux);
  AttackEvent e;
  e.uptimeSeconds = millis() / 1000;
  memcpy(e.sourceMac, sourceMac, 6);
  e.reasonCode = reasonCode;
  e.rssi = rssi;
  e.isDeauth = isDeauth;

  lastAttackUptime = millis() / 1000;
  totalAttacksThisSession++;

  pendingEventCopy = e;
  pendingEspNowEvent = true;
  portEXIT_CRITICAL_ISR(&eventMux);
}

// ---- Sniffer Callback ---------------------------------------------------
void IRAM_ATTR snifferCallback(void* buf, wifi_promiscuous_pkt_type_t type) {
  if (type != WIFI_PKT_MGMT) return;

  wifi_promiscuous_pkt_t* pkt = (wifi_promiscuous_pkt_t*)buf;
  const uint8_t* payload = pkt->payload;

  uint8_t frameType = (payload[0] & 0x0C) >> 2;
  uint8_t frameSubtype = (payload[0] & 0xF0) >> 4;

  bool isDeauth = (frameType == 0 && frameSubtype == 12);
  bool isDisassoc = (frameType == 0 && frameSubtype == 10);
  if (!isDeauth && !isDisassoc) return;

  const uint8_t* addr1 = payload + 4;
  const uint8_t* addr2 = payload + 10;
  const uint8_t* addr3 = payload + 16;

  bool targetsOurGateway = macEquals(addr1, TARGET_MAC) || macEquals(addr3, TARGET_MAC);
  if (!targetsOurGateway) return;

  uint8_t reasonCode = payload[24];
  int8_t rssi = pkt->rx_ctrl.rssi;

  addEvent(addr2, reasonCode, rssi, isDeauth);
}

// ---- OLED Routines (Fixed for 128x64) -----------------------------------
void showSplash() {
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_logisoso24_tf);
  int w = u8g2.getStrWidth("KIWI");
  u8g2.drawStr((128 - w) / 2, 28, "KIWI");

  u8g2.setFont(u8g2_font_6x10_tf);
  const char* sub1 = "Your WiFi Safety";
  int w1 = u8g2.getStrWidth(sub1);
  u8g2.drawStr((128 - w1) / 2, 44, sub1);

  const char* sub2 = "Companion";
  int w2 = u8g2.getStrWidth(sub2);
  u8g2.drawStr((128 - w2) / 2, 58, sub2);
  u8g2.sendBuffer();
  delay(3000);
}

void updateOled() {
  unsigned long nowSec = millis() / 1000;
  bool underAttack = (lastAttackUptime != 0) && (nowSec - lastAttackUptime <= 3);

  u8g2.clearBuffer();

  // Status Title (helvB10 fits completely without side cut-off)
  u8g2.setFont(u8g2_font_helvB10_tf);
  const char* statusWord = underAttack ? "UNDER ATTACK" : "PROTECTED";
  int w = u8g2.getStrWidth(statusWord);
  u8g2.drawStr((128 - w) / 2, 20, statusWord);

  // Line 2: Monitored SSID Name (or Warning during attack)
  u8g2.setFont(u8g2_font_6x10_tf);
  const char* line2Text = underAttack ? "! ATTACK DETECTED !" : TARGET_SSID;
  int subW = u8g2.getStrWidth(line2Text);
  u8g2.drawStr((128 - subW) / 2, 38, line2Text);

  // Line 3: Target MAC
  String macLine = macToString(TARGET_MAC);
  int macW = u8g2.getStrWidth(macLine.c_str());
  u8g2.drawStr((128 - macW) / 2, 56, macLine.c_str());

  u8g2.sendBuffer();
}

// ---- Hardware Alert Routine ---------------------------------------------
void tickAlerts() {
  unsigned long nowSec = millis() / 1000;
  bool underAttack = (lastAttackUptime != 0) && (nowSec - lastAttackUptime <= 3);

  if (!underAttack) {
    digitalWrite(BUZZER_PIN, LOW);
    digitalWrite(LED_PIN, LOW);
    return;
  }

  // Intermittent beep/flash during attack: 100ms ON / 100ms OFF / 100ms ON / 700ms OFF
  unsigned long cycle = millis() % 1000;
  bool active = (cycle < 100) || (cycle >= 200 && cycle < 300);

  digitalWrite(BUZZER_PIN, active ? HIGH : LOW);
  digitalWrite(LED_PIN, active ? HIGH : LOW);
}

// ---- ESP-NOW Setup & Loop -----------------------------------------------
void setupEspNow() {
  if (esp_now_init() != ESP_OK) return;

  esp_now_peer_info_t peer = {};
  memcpy(peer.peer_addr, COMPANION_MAC, 6);
  peer.channel = TARGET_CHANNEL;
  peer.encrypt = false;
  esp_now_add_peer(&peer);
}

void tickEspNow() {
  if (pendingEspNowEvent) {
    AttackEvent evCopy;
    portENTER_CRITICAL(&eventMux);
    evCopy = pendingEventCopy;
    pendingEspNowEvent = false;
    portEXIT_CRITICAL(&eventMux);

    SentinelMessage msg = {};
    msg.msgType = 1;
    msg.uptimeSeconds = millis() / 1000;
    msg.totalAttacks = totalAttacksThisSession;
    memcpy(msg.targetMac, TARGET_MAC, 6);
    msg.channel = TARGET_CHANNEL;
    memcpy(msg.sourceMac, evCopy.sourceMac, 6);
    msg.reasonCode = evCopy.reasonCode;
    msg.rssi = evCopy.rssi;
    msg.isDeauth = evCopy.isDeauth ? 1 : 0;

    esp_now_send(COMPANION_MAC, (uint8_t*)&msg, sizeof(msg));
    lastHeartbeatMs = millis();
    return;
  }

  unsigned long now = millis();
  if (now - lastHeartbeatMs >= 3000) {
    lastHeartbeatMs = now;
    SentinelMessage msg = {};
    msg.msgType = 0;
    msg.uptimeSeconds = millis() / 1000;
    msg.totalAttacks = totalAttacksThisSession;
    memcpy(msg.targetMac, TARGET_MAC, 6);
    msg.channel = TARGET_CHANNEL;
    esp_now_send(COMPANION_MAC, (uint8_t*)&msg, sizeof(msg));
  }
}

// ---- Setup & Loop -------------------------------------------------------
void setup() {
  Serial.begin(115200);

  // Outputs initialization and self-test pulse
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, HIGH);
  digitalWrite(LED_PIN, HIGH);
  delay(150);
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(LED_PIN, LOW);

  // Initialize display
  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  u8g2.begin();
  showSplash();
  updateOled();

  // Radio initialization in STA mode (no AP broadcast)
  WiFi.mode(WIFI_STA);
  esp_wifi_set_promiscuous(true);
  esp_wifi_set_promiscuous_rx_cb(&snifferCallback);
  esp_wifi_set_channel(TARGET_CHANNEL, WIFI_SECOND_CHAN_NONE);

  setupEspNow();
}

void loop() {
  unsigned long now = millis();
  if (now - lastOledUpdate >= 500) {
    lastOledUpdate = now;
    updateOled();
  }

  tickAlerts();
  tickEspNow();
}