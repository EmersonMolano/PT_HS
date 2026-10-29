-- Permite mover una placa entre registros lógicos del mismo usuario.
-- El hardwareId permanece asociado a un único dispositivo a la vez.
CREATE OR REPLACE FUNCTION device.fn_switch_device_hardware(
    p_device_id UUID,
    p_hardware_id VARCHAR(32)
)
RETURNS TABLE(
    device_id UUID,
    code VARCHAR(100),
    name VARCHAR(100),
    type VARCHAR(50),
    location VARCHAR(120),
    manufacturer VARCHAR(100),
    model VARCHAR(100),
    umbral_alerta DECIMAL(10,4),
    status VARCHAR(20),
    hardware_id VARCHAR(32),
    provisioning_status VARCHAR(24),
    provisioning_error VARCHAR(255),
    provisioning_updated_at TIMESTAMPTZ,
    provisioned_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = device, home, user_account, public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_hardware_id VARCHAR(32);
    v_target_hardware_id VARCHAR(32);
    v_previous_device_id UUID;
BEGIN
    v_user_id := user_account.fn_app_current_user_id();
    v_hardware_id := NULLIF(btrim(p_hardware_id), '');

    IF v_user_id IS NULL
       OR NOT user_account.fn_app_has_permission('devices.manage')
       OR NOT device.fn_can_manage_device(p_device_id, v_user_id) THEN
        RAISE EXCEPTION 'La cuenta no puede asociar hardware a este dispositivo'
            USING ERRCODE = '42501';
    END IF;

    IF v_hardware_id IS NULL OR v_hardware_id !~ '^[A-Za-z0-9_-]{3,32}$' THEN
        RAISE EXCEPTION 'hardwareId debe tener entre 3 y 32 caracteres seguros';
    END IF;

    SELECT d.hardware_id
      INTO v_target_hardware_id
      FROM device.device d
     WHERE d.device_id = p_device_id
     FOR UPDATE;

    IF v_target_hardware_id IS NOT NULL AND v_target_hardware_id <> v_hardware_id THEN
        RAISE EXCEPTION 'El dispositivo destino ya esta asociado a otra placa'
            USING ERRCODE = '23505';
    END IF;

    SELECT d.device_id
      INTO v_previous_device_id
      FROM device.device d
     WHERE d.hardware_id = v_hardware_id
       AND d.device_id <> p_device_id
     FOR UPDATE;

    IF v_previous_device_id IS NOT NULL THEN
        IF NOT device.fn_can_manage_device(v_previous_device_id, v_user_id) THEN
            RAISE EXCEPTION 'El hardware ya esta asociado a otro dispositivo no administrable'
                USING ERRCODE = '23505';
        END IF;

        UPDATE device.device d
           SET hardware_id = NULL,
               connectivity_status = 'OFFLINE',
               last_connection_at = NULL,
               last_ip = NULL,
               wifi_ssid = NULL,
               wifi_rssi_dbm = NULL,
               signal_quality = NULL,
               provisioning_status = 'PENDING',
               provisioning_error = NULL,
               provisioning_updated_at = now(),
               provisioned_at = NULL,
               updated_at = now()
         WHERE d.device_id = v_previous_device_id;
    END IF;

    RETURN QUERY
    SELECT *
      FROM device.fn_claim_provisioned_device(p_device_id, v_hardware_id);
END;
$$;

COMMENT ON FUNCTION device.fn_switch_device_hardware(UUID, VARCHAR) IS
'Mueve de forma controlada una placa entre dispositivos que el usuario puede administrar, manteniendo una sola asociacion fisica activa.';
