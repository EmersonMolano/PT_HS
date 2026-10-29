-- Restores the four logical records; suspended home assignments remain suspended.
INSERT INTO device.logical_device_group_member (device_id, group_key, is_primary)
SELECT d.device_id,
       'ESP32-HS-01',
       d.code = 'HS-7A3F91C8D2E4'
  FROM device.device d
 WHERE d.code IN (
       'HS-7A3F91C8D2E4',
       'HS-B6E04D79A153',
       'HS-2C8A5F01E7B9',
       'HS-141F47470968'
 )
ON CONFLICT (device_id) DO UPDATE
   SET group_key = EXCLUDED.group_key,
       is_primary = EXCLUDED.is_primary;

UPDATE device.device d
   SET status = 'Active',
       suspension_reason = NULL,
       changed_at_status = now(),
       hardware_id = p.hardware_id,
       connectivity_status = 'UNKNOWN',
       provisioning_status = 'PENDING',
       provisioning_error = NULL,
       provisioning_updated_at = now(),
       provisioned_at = NULL,
       updated_at = now()
  FROM device.device p
 WHERE d.code IN (
       'HS-B6E04D79A153',
       'HS-2C8A5F01E7B9',
       'HS-141F47470968'
   )
   AND p.code = 'HS-7A3F91C8D2E4';
