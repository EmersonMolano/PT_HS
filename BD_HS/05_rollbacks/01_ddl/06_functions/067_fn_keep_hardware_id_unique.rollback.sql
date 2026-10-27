DROP TRIGGER IF EXISTS tr_device_hardware_id_unique ON device.device;
DROP FUNCTION IF EXISTS device.fn_keep_hardware_id_unique();
