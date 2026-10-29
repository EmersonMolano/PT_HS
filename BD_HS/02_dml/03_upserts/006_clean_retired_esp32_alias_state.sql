-- The single-device migration retired these aliases. Clear retained MQTT state
-- that was replayed after the first cleanup; preserve identity and reading history.
UPDATE home.home_device
   SET status = 'Suspended',
       suspended_at = COALESCE(suspended_at, now())
 WHERE device_id IN (
       SELECT device_id
         FROM device.device
        WHERE code IN (
            'HS-B6E04D79A153',
            'HS-2C8A5F01E7B9',
            'HS-141F47470968'
        )
   )
   AND status = 'Active';

UPDATE device.device
   SET location = NULL,
       manufacturer = NULL,
       model = NULL,
       umbral_alerta = NULL,
       hardware_id = NULL,
       connectivity_status = 'UNKNOWN',
       provisioning_status = 'PENDING',
       provisioning_error = NULL,
       provisioning_updated_at = now(),
       provisioned_at = NULL,
       firmware_version = NULL,
       last_connection_at = NULL,
       last_ip = NULL,
       wifi_ssid = NULL,
       wifi_rssi_dbm = NULL,
       signal_quality = NULL,
       battery_level = NULL,
       updated_at = now()
 WHERE code IN (
       'HS-B6E04D79A153',
       'HS-2C8A5F01E7B9',
       'HS-141F47470968'
   )
   AND status = 'Suspended';
