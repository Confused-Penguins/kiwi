/*
  KIWI Companion — ESP-NOW to BLE Bridge Node
  ===========================================
  Receives SentinelMessage structs via ESP-NOW on Channel 1
  and streams status to the Web Dashboard via BLE notifications.
*/

#include <WiFi.h>
#include <esp_wifi.h>
#include <esp_now.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define TARGET_CHANNEL 1

// ---- BLE UUIDs -------------------------------------------------------------
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define STATUS_CHAR_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// ---- Packet Definition (Must match Sentinel byte-for-byte) -----------------
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

BLECharacteristic *pStatusCharacteristic;
bool deviceConnected = false;

volatile bool newEventReceived = false;
SentinelMessage latestMsg;
unsigned long lastAttackTimeMs = 0;
unsigned long lastBleHeartbeat = 0;

// ---- BLE Callbacks ---------------------------------------------------------
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("[BLE] Client connected to Companion.");
  }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("[BLE] Client disconnected. Re-advertising...");
    BLEDevice::startAdvertising();
  }
};

// ---- ESP-NOW Receive Callback ----------------------------------------------
#if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
void onDataRecv(const esp_now_recv_info_t* info, const uint8_t* incomingData, int len) {
#else
void onDataRecv(const uint8_t* mac, const uint8_t* incomingData, int len) {
#endif
  if (len != sizeof(SentinelMessage)) {
    Serial.printf("[ESP-NOW] Packet length mismatch: received %d, expected %d\n", len, sizeof(SentinelMessage));
    return;
  }

  memcpy((void*)&latestMsg, incomingData, sizeof(SentinelMessage));

  if (latestMsg.msgType == 1) {
    lastAttackTimeMs = millis();
    Serial.println("[ESP-NOW] Attack packet received!");
  } else {
    Serial.println("[ESP-NOW] Heartbeat received.");
  }
  newEventReceived = true;
}

// ---- Formatting Helpers ----------------------------------------------------
String macToString(const uint8_t* mac) {
  char buf[18];
  snprintf(buf, sizeof(buf), "%02X:%02X:%02X:%02X:%02X:%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  return String(buf);
}

void notifyDashboard() {
  if (!deviceConnected) return;

  bool underAttack = (millis() - lastAttackTimeMs <= 3000) && (lastAttackTimeMs > 0);
  const char* statusStr = underAttack ? "UNDER_ATTACK" : "PROTECTED";

  char jsonBuf[160];
  snprintf(jsonBuf, sizeof(jsonBuf),
           "{\"status\":\"%s\",\"attacks\":%lu,\"attacker\":\"%s\",\"rssi\":%d,\"type\":%d}",
           statusStr,
           latestMsg.totalAttacks,
           macToString(latestMsg.sourceMac).c_str(),
           latestMsg.rssi,
           latestMsg.isDeauth);

  pStatusCharacteristic->setValue((uint8_t*)jsonBuf, strlen(jsonBuf));
  pStatusCharacteristic->notify();
}

// ---- Setup & Loop ----------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n[INIT] Booting KIWI Companion Bridge Node...");

  // 1. Set Wi-Fi to Station mode and lock Channel 1
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  esp_wifi_set_channel(TARGET_CHANNEL, WIFI_SECOND_CHAN_NONE);

  // Print actual MAC so you can verify with Sentinel's COMPANION_MAC
  Serial.print("[INFO] Companion Wi-Fi MAC: ");
  Serial.println(WiFi.macAddress());

  // 2. Initialize ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("[ESP-NOW] Initialization failed!");
    return;
  }
  esp_now_register_recv_cb(onDataRecv);
  Serial.println("[ESP-NOW] Receiver ready on Channel 1.");

  // 3. Initialize BLE GATT Server
  BLEDevice::init("KIWI-Companion");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pStatusCharacteristic = pService->createCharacteristic(
                            STATUS_CHAR_UUID,
                            BLECharacteristic::PROPERTY_READ |
                            BLECharacteristic::PROPERTY_NOTIFY
                          );
  pStatusCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Advertising as 'KIWI-Companion'. Ready.");
}

void loop() {
  // Push right away when a new packet arrives from the Sentinel
  if (newEventReceived) {
    newEventReceived = false;
    notifyDashboard();
  }

  // Fallback 1-second interval to update heartbeat/status on dashboard
  unsigned long now = millis();
  if (now - lastBleHeartbeat >= 1000) {
    lastBleHeartbeat = now;
    notifyDashboard();
  }
}