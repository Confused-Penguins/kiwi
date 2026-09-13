#ifndef KIWI_OLED_DISPLAY_H
#define KIWI_OLED_DISPLAY_H

#include <Arduino.h>

// Set to 1 to enable I2C SSD1306 OLED status display via U8g2
#ifndef USE_OLED
#define USE_OLED 0
#endif

void display_init();
void display_update(const char* ssid, const char* ip_str, const char* dev_id, bool has_cert, int connected_clients);
void display_show_auth_event(const char* event_name, bool success);

#endif // KIWI_OLED_DISPLAY_H
