DELETE FROM device.device d
WHERE d.code = 'HS-141F47470968'
  AND d.hardware_id IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM home.home_device hd
      WHERE hd.device_id = d.device_id
  )
  AND NOT EXISTS (
      SELECT 1
      FROM consumption.sensor_reading sr
      WHERE sr.device_id = d.device_id
  );
