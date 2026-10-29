REVOKE ALL ON FUNCTION device.fn_switch_device_hardware(UUID, VARCHAR) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION device.fn_switch_device_hardware(UUID, VARCHAR) TO hidro_smart_app;
