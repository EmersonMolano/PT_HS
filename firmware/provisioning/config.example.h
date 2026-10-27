#pragma once

#define HIDROSMART_WIFI_SSID "CAMBIA_WIFI_SSID"
#define HIDROSMART_WIFI_PASSWORD "CAMBIA_WIFI_PASSWORD"
// Nombre DNS estable de la red local. Debe resolver hacia el PC/servidor que
// publica Mosquitto; no uses "mosquitto", que solo existe dentro de Docker.
#define HIDROSMART_MQTT_HOST "hidrosmart-broker.local"
#define HIDROSMART_MQTT_PORT 1883
// For Flespi production set TLS to 1, host to mqtt.flespi.io and port to 8883.
// Keep TLS off only for the isolated local Mosquitto development broker.
#ifndef HIDROSMART_MQTT_USE_TLS
#define HIDROSMART_MQTT_USE_TLS 0
#endif
// Vacio: usa el hardwareId HS-XXXXXX generado por el ESP32.
// Para una placa preasignada, usa UN codigo por ESP32, por ejemplo
// "HS-7A3F91C8D2E4", "HS-B6E04D79A153" o "HS-2C8A5F01E7B9".
// No reutilices el mismo codigo en dos placas.
#define HIDROSMART_DEVICE_CODE ""
// Use one dedicated Flespi ACL token per ESP32 as the MQTT username.
// Flespi does not require a password when the token is the username.
// Never commit config.h or distribute the same token to multiple devices.
#define HIDROSMART_MQTT_USERNAME ""
#define HIDROSMART_MQTT_PASSWORD ""
#define HIDROSMART_FIRMWARE_VERSION "1.1.0"
#define HIDROSMART_FLOW_PIN 27
#define HIDROSMART_FLOW_FACTOR 7.5f
#define HIDROSMART_SAMPLE_INTERVAL_MS 5000UL
#define HIDROSMART_MQTT_KEEPALIVE_SECONDS 30
