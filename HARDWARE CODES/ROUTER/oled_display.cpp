#include "oled_display.h"

#if USE_OLED
#include <U8g2lib.h>
#include <Wire.h>

// Standard 128x64 I2C SSD1306 OLED (SDA=21, SCL=22 on ESP32 Dev Module)
static U8G2_SSD1306_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, /* reset=*/ U8X8_PIN_NONE);

void display_init() {
    u8g2.begin();
    u8g2.clearBuffer();
    u8g2.setFont(u8g2_font_ncenB08_tr);
    u8g2.drawStr(10, 20, "KIWI GATEWAY");
    u8g2.drawStr(10, 40, "Initializing...");
    u8g2.sendBuffer();
}

void display_update(const char* ssid, const char* ip_str, const char* dev_id, bool has_cert, int connected_clients) {
    u8g2.clearBuffer();
    
    // Header
    u8g2.setFont(u8g2_font_helvB08_tr);
    u8g2.drawStr(0, 10, "KIWI GATEWAY");
    if (has_cert) {
        u8g2.drawStr(85, 10, "[CERT OK]");
    } else {
        u8g2.drawStr(80, 10, "[NO CERT]");
    }
    
    u8g2.drawLine(0, 13, 127, 13);
    
    // Body lines
    u8g2.setFont(u8g2_font_6x10_tf);
    char buf[32];
    snprintf(buf, sizeof(buf), "ID: %s", dev_id);
    u8g2.drawStr(0, 26, buf);
    
    snprintf(buf, sizeof(buf), "AP: %s", ssid);
    u8g2.drawStr(0, 39, buf);
    
    snprintf(buf, sizeof(buf), "IP: %s", ip_str);
    u8g2.drawStr(0, 52, buf);
    
    snprintf(buf, sizeof(buf), "Clients: %d", connected_clients);
    u8g2.drawStr(0, 63, buf);
    
    u8g2.sendBuffer();
}

void display_show_auth_event(const char* event_name, bool success) {
    u8g2.clearBuffer();
    u8g2.setFont(u8g2_font_helvB08_tr);
    u8g2.drawStr(15, 20, "AUTH EVENT");
    u8g2.setFont(u8g2_font_6x10_tf);
    u8g2.drawStr(0, 38, event_name);
    u8g2.setFont(u8g2_font_helvB10_tr);
    if (success) {
        u8g2.drawStr(20, 56, "[ AUTHORIZED ]");
    } else {
        u8g2.drawStr(25, 56, "[ REJECTED ]");
    }
    u8g2.sendBuffer();
}

#else
// Zero-cost stubs when OLED display is disabled
void display_init() {}
void display_update(const char*, const char*, const char*, bool, int) {}
void display_show_auth_event(const char*, bool) {}
#endif
