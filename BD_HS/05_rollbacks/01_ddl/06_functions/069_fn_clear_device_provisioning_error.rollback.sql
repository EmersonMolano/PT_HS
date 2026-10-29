-- Restore the preceding group-aware status function without the stale-error cleanup.
CREATE OR REPLACE FUNCTION device.fn_record_device_status(
    p_device_code VARCHAR(100), p_connectivity_status VARCHAR(20),
    p_event_at TIMESTAMPTZ, p_firmware_version VARCHAR(20),
    p_wifi_rssi_dbm INTEGER, p_signal_quality INTEGER, p_battery_level INTEGER,
    p_last_ip VARCHAR(45), p_hardware_id VARCHAR(32), p_provisioning_status VARCHAR(24)
)
RETURNS TABLE(
    device_id UUID, code VARCHAR(100), administrative_status VARCHAR(20),
    connectivity_status VARCHAR(20), last_connection_at TIMESTAMPTZ,
    hardware_id VARCHAR(32), provisioning_status VARCHAR(24),
    provisioning_updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, device, home, user_account, public, pg_temp
AS $$
DECLARE
    v_event_at TIMESTAMPTZ := COALESCE(p_event_at, now());
    v_provisioning_status VARCHAR(24) := NULLIF(upper(btrim(p_provisioning_status)), '');
    v_group_key VARCHAR(64);
BEGIN
    IF p_device_code IS NULL OR btrim(p_device_code) = ''
       OR p_connectivity_status NOT IN ('ONLINE', 'OFFLINE', 'ERROR') THEN
        RAISE EXCEPTION 'El estado MQTT no cumple el contrato';
    END IF;
    IF v_event_at > now() + INTERVAL '5 minutes' THEN
        RAISE EXCEPTION 'El estado MQTT tiene un timestamp futuro no permitido';
    END IF;
    IF v_provisioning_status IS NOT NULL
       AND v_provisioning_status NOT IN ('PENDING', 'BLE_READY', 'WIFI_CONNECTED', 'MQTT_CONNECTED', 'COMPLETE', 'FAILED') THEN
        RAISE EXCEPTION 'El estado de provisionamiento no cumple el contrato';
    END IF;
    IF p_hardware_id IS NOT NULL AND NULLIF(btrim(p_hardware_id), '') IS NOT NULL
       AND btrim(p_hardware_id) !~ '^[A-Za-z0-9_-]{3,32}$' THEN
        RAISE EXCEPTION 'hardwareId no cumple el contrato';
    END IF;
    IF (p_wifi_rssi_dbm IS NOT NULL AND p_wifi_rssi_dbm NOT BETWEEN -127 AND 0)
       OR (p_signal_quality IS NOT NULL AND p_signal_quality NOT BETWEEN 0 AND 100)
       OR (p_battery_level IS NOT NULL AND p_battery_level NOT BETWEEN 0 AND 100) THEN
        RAISE EXCEPTION 'Las metricas de conectividad estan fuera de rango';
    END IF;

    SELECT gm.group_key INTO v_group_key
      FROM device.logical_device_group_member gm
      JOIN device.device d ON d.device_id = gm.device_id
     WHERE d.code = btrim(p_device_code);

    RETURN QUERY
    WITH updated AS (
        UPDATE device.device d
           SET connectivity_status = CASE WHEN p_connectivity_status = 'ONLINE' THEN 'ONLINE'
                                           WHEN p_connectivity_status = 'ERROR' THEN 'DEGRADED'
                                           ELSE 'OFFLINE' END,
               last_connection_at = CASE WHEN p_connectivity_status = 'ONLINE' THEN v_event_at ELSE d.last_connection_at END,
               firmware_version = COALESCE(NULLIF(btrim(p_firmware_version), ''), d.firmware_version),
               wifi_rssi_dbm = COALESCE(p_wifi_rssi_dbm, d.wifi_rssi_dbm),
               signal_quality = COALESCE(p_signal_quality, d.signal_quality),
               battery_level = COALESCE(p_battery_level, d.battery_level),
               last_ip = COALESCE(NULLIF(btrim(p_last_ip), ''), d.last_ip),
               hardware_id = COALESCE(NULLIF(btrim(p_hardware_id), ''), d.hardware_id),
               provisioning_status = COALESCE(v_provisioning_status,
                   CASE WHEN p_connectivity_status = 'ONLINE' AND d.provisioning_status = 'PENDING'
                        THEN 'MQTT_CONNECTED' ELSE d.provisioning_status END),
               provisioning_updated_at = CASE
                   WHEN v_provisioning_status IS NOT NULL OR NULLIF(btrim(p_hardware_id), '') IS NOT NULL
                        OR p_connectivity_status = 'ONLINE' THEN now()
                   ELSE d.provisioning_updated_at END,
               provisioned_at = CASE WHEN v_provisioning_status = 'COMPLETE'
                                     THEN COALESCE(d.provisioned_at, now()) ELSE d.provisioned_at END,
               updated_at = now()
          FROM (SELECT d2.device_id FROM device.device d2 WHERE d2.code = btrim(p_device_code)
                UNION
                SELECT gm.device_id FROM device.logical_device_group_member gm WHERE gm.group_key = v_group_key) members
         WHERE d.device_id = members.device_id
         RETURNING d.device_id, d.code, d.status, d.connectivity_status, d.last_connection_at,
                   d.hardware_id, d.provisioning_status, d.provisioning_updated_at
    )
    SELECT updated.device_id, updated.code, updated.status, updated.connectivity_status,
           updated.last_connection_at, updated.hardware_id, updated.provisioning_status,
           updated.provisioning_updated_at
      FROM updated WHERE updated.code = btrim(p_device_code);

    IF FOUND THEN
        INSERT INTO device.device_telemetry_history
            (device_id, recorded_at, wifi_rssi_dbm, signal_quality, battery_level)
        SELECT d.device_id, now(), p_wifi_rssi_dbm, p_signal_quality, p_battery_level
          FROM device.device d WHERE d.code = btrim(p_device_code);
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION device.fn_record_device_status(VARCHAR, VARCHAR, TIMESTAMPTZ, VARCHAR, INTEGER, INTEGER, INTEGER, VARCHAR, VARCHAR, VARCHAR) FROM PUBLIC;
