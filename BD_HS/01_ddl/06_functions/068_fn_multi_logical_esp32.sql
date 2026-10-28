-- Permite compartir una placa solo entre miembros del mismo grupo logico.
-- La unicidad global de hardware_id se sustituye por el trigger serializado
-- que permite duplicados dentro del mismo grupo y los rechaza entre grupos.
DROP INDEX IF EXISTS device.uq_device_hardware_id;

CREATE OR REPLACE FUNCTION device.fn_keep_hardware_id_unique()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, device, public, pg_temp
AS $$
DECLARE
    v_group_key VARCHAR(64);
BEGIN
    IF NEW.hardware_id IS NULL OR btrim(NEW.hardware_id) = '' THEN
        RETURN NEW;
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(btrim(NEW.hardware_id)));

    SELECT gm.group_key INTO v_group_key
      FROM device.logical_device_group_member gm
     WHERE gm.device_id = NEW.device_id;

    IF EXISTS (
        SELECT 1
          FROM device.device d
          LEFT JOIN device.logical_device_group_member gm ON gm.device_id = d.device_id
         WHERE d.hardware_id = NEW.hardware_id
           AND d.device_id <> NEW.device_id
           AND (v_group_key IS NULL OR gm.group_key IS DISTINCT FROM v_group_key)
    ) THEN
        IF TG_OP = 'UPDATE' THEN
            NEW.hardware_id := OLD.hardware_id;
        ELSE
            RAISE EXCEPTION 'hardwareId ya esta asociado a otro dispositivo o grupo'
                USING ERRCODE = '23505';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- Un estado publicado en cualquiera de los alias describe la unica placa.
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
    IF v_event_at > now() + INTERVAL '5 minutes' THEN RAISE EXCEPTION 'El estado MQTT tiene un timestamp futuro no permitido'; END IF;
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

-- Compatibilidad con clientes antiguos de 8 parametros; tambien sincroniza el grupo.
CREATE OR REPLACE FUNCTION device.fn_record_device_status(
    p_device_code VARCHAR(100), p_connectivity_status VARCHAR(20),
    p_event_at TIMESTAMPTZ, p_firmware_version VARCHAR(20),
    p_wifi_rssi_dbm INTEGER, p_signal_quality INTEGER, p_battery_level INTEGER,
    p_last_ip VARCHAR(45)
)
RETURNS TABLE(
    device_id UUID, code VARCHAR(100), administrative_status VARCHAR(20),
    connectivity_status VARCHAR(20), last_connection_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, device, public, pg_temp
AS $$
    SELECT s.device_id, s.code, s.administrative_status,
           s.connectivity_status, s.last_connection_at
      FROM device.fn_record_device_status(
          p_device_code, p_connectivity_status, p_event_at, p_firmware_version,
          p_wifi_rssi_dbm, p_signal_quality, p_battery_level, p_last_ip,
          NULL::VARCHAR(32), NULL::VARCHAR(24)
      ) s;
$$;

CREATE OR REPLACE FUNCTION device.fn_record_device_wifi_ssid(
    p_device_code VARCHAR(100), p_wifi_ssid VARCHAR(32)
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, device, public, pg_temp
AS $$
DECLARE v_updated BOOLEAN;
BEGIN
    IF p_device_code IS NULL OR btrim(p_device_code) = '' THEN RAISE EXCEPTION 'El codigo del dispositivo es obligatorio'; END IF;
    IF p_wifi_ssid IS NOT NULL AND char_length(btrim(p_wifi_ssid)) > 32 THEN RAISE EXCEPTION 'El SSID no puede superar 32 caracteres'; END IF;
    UPDATE device.device d
       SET wifi_ssid = NULLIF(btrim(p_wifi_ssid), ''), updated_at = now()
     WHERE d.device_id IN (
         SELECT gm.device_id FROM device.logical_device_group_member gm
          WHERE gm.group_key = (SELECT gm2.group_key FROM device.logical_device_group_member gm2
                                 JOIN device.device d2 ON d2.device_id = gm2.device_id
                                WHERE d2.code = btrim(p_device_code))
     ) OR d.code = btrim(p_device_code);
    v_updated := FOUND;
    RETURN v_updated;
END;
$$;

-- Claim del mismo hardware por otro codigo del mismo grupo es permitido.
CREATE OR REPLACE FUNCTION device.fn_claim_provisioned_device(
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
    v_target_group VARCHAR(64);
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

    PERFORM pg_advisory_xact_lock(hashtext(v_hardware_id));
    SELECT d.hardware_id INTO v_target_hardware_id
      FROM device.device d
     WHERE d.device_id = p_device_id
     FOR UPDATE;
    IF v_target_hardware_id IS NOT NULL AND v_target_hardware_id <> v_hardware_id THEN
        RAISE EXCEPTION 'El dispositivo destino ya esta asociado a otra placa'
            USING ERRCODE = '23505';
    END IF;
    SELECT gm.group_key INTO v_target_group
      FROM device.logical_device_group_member gm
     WHERE gm.device_id = p_device_id;

    IF EXISTS (
        SELECT 1
          FROM device.device other_device
          LEFT JOIN device.logical_device_group_member other_group
            ON other_group.device_id = other_device.device_id
         WHERE other_device.hardware_id = v_hardware_id
           AND other_device.device_id <> p_device_id
           AND (v_target_group IS NULL OR other_group.group_key IS DISTINCT FROM v_target_group)
    ) THEN
        RAISE EXCEPTION 'El hardware ya esta asociado a otro dispositivo'
            USING ERRCODE = '23505';
    END IF;

    RETURN QUERY
    UPDATE device.device d
       SET hardware_id = v_hardware_id,
           provisioning_status = CASE
               WHEN d.hardware_id IS DISTINCT FROM v_hardware_id THEN 'BLE_READY'
               ELSE d.provisioning_status
           END,
           provisioning_error = NULL,
           provisioning_updated_at = now(),
           updated_at = now()
     WHERE d.device_id = p_device_id
     RETURNING d.device_id, d.code, d.name, d.type, d.location, d.manufacturer,
               d.model, d.umbral_alerta, d.status, d.hardware_id,
               d.provisioning_status, d.provisioning_error,
               d.provisioning_updated_at, d.provisioned_at;
END;
$$;

-- Cambiar de codigo dentro del grupo conserva las asignaciones de los demas alias.
CREATE OR REPLACE FUNCTION device.fn_switch_device_hardware(
    p_device_id UUID,
    p_hardware_id VARCHAR(32)
)
RETURNS TABLE(
    device_id UUID, code VARCHAR(100), name VARCHAR(100), type VARCHAR(50),
    location VARCHAR(120), manufacturer VARCHAR(100), model VARCHAR(100),
    umbral_alerta DECIMAL(10,4), status VARCHAR(20), hardware_id VARCHAR(32),
    provisioning_status VARCHAR(24), provisioning_error VARCHAR(255),
    provisioning_updated_at TIMESTAMPTZ, provisioned_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = device, home, user_account, public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_hardware_id VARCHAR(32);
    v_target_hardware_id VARCHAR(32);
    v_target_group VARCHAR(64);
    v_previous_device UUID;
    v_previous_group VARCHAR(64);
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

    PERFORM pg_advisory_xact_lock(hashtext(v_hardware_id));
    SELECT d.hardware_id INTO v_target_hardware_id
      FROM device.device d
     WHERE d.device_id = p_device_id
     FOR UPDATE;
    IF v_target_hardware_id IS NOT NULL AND v_target_hardware_id <> v_hardware_id THEN
        RAISE EXCEPTION 'El dispositivo destino ya esta asociado a otra placa'
            USING ERRCODE = '23505';
    END IF;
    SELECT gm.group_key INTO v_target_group
      FROM device.logical_device_group_member gm
     WHERE gm.device_id = p_device_id;

    SELECT d.device_id, gm.group_key
      INTO v_previous_device, v_previous_group
      FROM device.device d
      LEFT JOIN device.logical_device_group_member gm ON gm.device_id = d.device_id
     WHERE d.hardware_id = v_hardware_id AND d.device_id <> p_device_id
     ORDER BY gm.is_primary DESC NULLS LAST, d.device_id
     LIMIT 1
     FOR UPDATE OF d;

    IF v_previous_device IS NOT NULL
       AND (v_target_group IS NULL OR v_previous_group IS DISTINCT FROM v_target_group) THEN
        IF NOT device.fn_can_manage_device(v_previous_device, v_user_id) THEN
            RAISE EXCEPTION 'El hardware ya esta asociado a otro dispositivo no administrable'
                USING ERRCODE = '23505';
        END IF;

        IF v_previous_group IS NULL THEN
            UPDATE device.device d SET hardware_id = NULL,
                   connectivity_status = 'OFFLINE', last_connection_at = NULL,
                   last_ip = NULL, wifi_ssid = NULL, wifi_rssi_dbm = NULL,
                   signal_quality = NULL, provisioning_status = 'PENDING',
                   provisioning_error = NULL, provisioning_updated_at = now(),
                   provisioned_at = NULL, updated_at = now()
             WHERE d.device_id = v_previous_device;
        ELSE
            UPDATE device.device d SET hardware_id = NULL,
                   connectivity_status = 'OFFLINE', last_connection_at = NULL,
                   last_ip = NULL, wifi_ssid = NULL, wifi_rssi_dbm = NULL,
                   signal_quality = NULL, provisioning_status = 'PENDING',
                   provisioning_error = NULL, provisioning_updated_at = now(),
                   provisioned_at = NULL, updated_at = now()
             FROM device.logical_device_group_member gm
             WHERE gm.device_id = d.device_id AND gm.group_key = v_previous_group;
        END IF;
    END IF;

    RETURN QUERY SELECT * FROM device.fn_claim_provisioned_device(p_device_id, v_hardware_id);
END;
$$;

-- Vincular cualquiera de los cuatro codigos vincula el grupo fisico completo.
CREATE OR REPLACE FUNCTION device.fn_link_device_to_home(
    p_code VARCHAR(100),
    p_home_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = device, home, user_account, public, pg_temp
AS $$
DECLARE
    v_device_id UUID;
    v_group_key VARCHAR(64);
    v_user_id UUID;
BEGIN
    v_user_id := user_account.fn_app_current_user_id();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'El usuario autenticado es obligatorio'; END IF;
    IF NOT user_account.fn_app_has_permission('devices.manage')
       OR NOT home.fn_is_home_owner(p_home_id, v_user_id) THEN
        RAISE EXCEPTION 'La cuenta no puede vincular dispositivos a este hogar'
            USING ERRCODE = '42501';
    END IF;

    SELECT d.device_id, gm.group_key INTO v_device_id, v_group_key
      FROM device.device d
      LEFT JOIN device.logical_device_group_member gm ON gm.device_id = d.device_id
     WHERE d.code = btrim(p_code) AND d.status = 'Active'
     LIMIT 1;
    IF v_device_id IS NULL THEN RETURN NULL; END IF;

    IF v_group_key IS NULL THEN
        INSERT INTO home.home_device(home_id, device_id, status, suspended_at)
        VALUES (p_home_id, v_device_id, 'Active', NULL)
        ON CONFLICT (home_id, device_id) DO UPDATE SET status = 'Active', suspended_at = NULL;
    ELSE
        PERFORM pg_advisory_xact_lock(hashtext(v_group_key));
        IF EXISTS (
            SELECT 1 FROM device.logical_device_group_member gm
            JOIN home.home_device hd ON hd.device_id = gm.device_id AND hd.status = 'Active'
            WHERE gm.group_key = v_group_key AND hd.home_id <> p_home_id
        ) THEN
            RAISE EXCEPTION 'El ESP32 ya esta vinculado a otro hogar'
                USING ERRCODE = '23505';
        END IF;
        INSERT INTO home.home_device(home_id, device_id, status, suspended_at)
        SELECT p_home_id, gm.device_id, 'Active', NULL
          FROM device.logical_device_group_member gm
          JOIN device.device d ON d.device_id = gm.device_id AND d.status = 'Active'
         WHERE gm.group_key = v_group_key
        ON CONFLICT (home_id, device_id) DO UPDATE SET status = 'Active', suspended_at = NULL;
    END IF;
    RETURN v_device_id;
END;
$$;

CREATE OR REPLACE FUNCTION device.fn_link_device_to_home_by_hardware(
    p_hardware_id VARCHAR(32),
    p_home_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = device, home, user_account, public, pg_temp
AS $$
DECLARE
    v_code VARCHAR(100);
BEGIN
    IF user_account.fn_app_current_user_id() IS NULL THEN
        RAISE EXCEPTION 'El usuario autenticado es obligatorio';
    END IF;
    IF p_hardware_id IS NULL OR btrim(p_hardware_id) !~ '^[A-Za-z0-9_-]{3,32}$' THEN
        RAISE EXCEPTION 'hardwareId debe tener entre 3 y 32 caracteres seguros';
    END IF;
    SELECT d.code INTO v_code
      FROM device.device d
     WHERE d.hardware_id = btrim(p_hardware_id) AND d.status = 'Active'
     ORDER BY EXISTS (
         SELECT 1 FROM device.logical_device_group_member gm
          WHERE gm.device_id = d.device_id AND gm.is_primary
     ) DESC, d.code
     LIMIT 1;
    IF v_code IS NULL THEN RETURN NULL; END IF;
    RETURN device.fn_link_device_to_home(v_code, p_home_id);
END;
$$;

-- Toda ruta de ingesta contabiliza litros solo para el miembro principal.
CREATE OR REPLACE FUNCTION device.fn_ingest_sensor_reading(
    p_device_code VARCHAR(100), p_mqtt_message_id VARCHAR(100),
    p_consumption_liters NUMERIC, p_recorded_at TIMESTAMPTZ,
    p_flow_rate_lpm NUMERIC, p_total_liters NUMERIC, p_pulses INTEGER,
    p_sample_interval_seconds NUMERIC, p_wifi_rssi_dbm INTEGER,
    p_signal_quality INTEGER, p_battery_level INTEGER, p_voltage NUMERIC,
    p_temperature NUMERIC
)
RETURNS TABLE(inserted BOOLEAN, reading_id UUID, home_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, device, home, consumption, public, pg_temp
AS $$
DECLARE
    v_device_id UUID;
    v_home_id UUID;
    v_reading_id UUID;
    v_active_assignments INTEGER;
    v_timestamp_suspicious BOOLEAN;
    v_is_primary BOOLEAN := TRUE;
    v_consumption NUMERIC := p_consumption_liters;
BEGIN
    IF p_device_code IS NULL OR btrim(p_device_code) = ''
       OR p_consumption_liters IS NULL OR p_consumption_liters < 0 OR p_recorded_at IS NULL THEN
        RAISE EXCEPTION 'La lectura IoT no cumple el contrato minimo';
    END IF;
    IF p_recorded_at > now() + INTERVAL '5 minutes' THEN RAISE EXCEPTION 'La lectura IoT tiene un timestamp futuro no permitido'; END IF;
    IF (p_pulses IS NOT NULL AND p_pulses < 0)
       OR (p_sample_interval_seconds IS NOT NULL AND (p_sample_interval_seconds < 0.001 OR p_sample_interval_seconds > 3600))
       OR (p_wifi_rssi_dbm IS NOT NULL AND p_wifi_rssi_dbm NOT BETWEEN -127 AND 0)
       OR (p_signal_quality IS NOT NULL AND p_signal_quality NOT BETWEEN 0 AND 100)
       OR (p_battery_level IS NOT NULL AND p_battery_level NOT BETWEEN 0 AND 100)
       OR (p_voltage IS NOT NULL AND p_voltage NOT BETWEEN 0 AND 60)
       OR (p_temperature IS NOT NULL AND p_temperature NOT BETWEEN -55 AND 125) THEN
        RAISE EXCEPTION 'Las metricas IoT estan fuera de rango';
    END IF;

    SELECT gm.is_primary INTO v_is_primary
      FROM device.logical_device_group_member gm
      JOIN device.device d ON d.device_id = gm.device_id
     WHERE d.code = btrim(p_device_code);
    IF FOUND AND NOT v_is_primary THEN v_consumption := 0; END IF;

    SELECT count(*) INTO v_active_assignments
      FROM device.device d JOIN home.home_device hd ON hd.device_id = d.device_id
     WHERE d.code = btrim(p_device_code) AND d.status = 'Active' AND hd.status = 'Active';
    IF v_active_assignments = 0 THEN RAISE EXCEPTION 'El dispositivo no esta vinculado a un hogar activo'; END IF;
    IF v_active_assignments > 1 THEN RAISE EXCEPTION 'El dispositivo tiene asignaciones activas ambiguas'; END IF;

    SELECT d.device_id, hd.home_id INTO v_device_id, v_home_id
      FROM device.device d JOIN home.home_device hd ON hd.device_id = d.device_id
     WHERE d.code = btrim(p_device_code) AND d.status = 'Active' AND hd.status = 'Active';
    v_timestamp_suspicious := p_recorded_at < now() - INTERVAL '90 days';

    INSERT INTO consumption.sensor_reading AS sr
        (device_id, home_id, recorded_at, measured_at, received_at, timestamp_suspicious,
         consumption_liters, mqtt_message_id, flow_rate_lpm, total_liters, pulses,
         sample_interval_seconds, wifi_rssi_dbm, signal_quality, battery_level, voltage, temperature)
    VALUES
        (v_device_id, v_home_id, p_recorded_at, p_recorded_at, now(), v_timestamp_suspicious,
         v_consumption, NULLIF(btrim(p_mqtt_message_id), ''), p_flow_rate_lpm, p_total_liters,
         p_pulses, p_sample_interval_seconds, p_wifi_rssi_dbm, p_signal_quality,
         p_battery_level, p_voltage, p_temperature)
    ON CONFLICT (device_id, mqtt_message_id) WHERE mqtt_message_id IS NOT NULL DO NOTHING
    RETURNING sr.reading_id INTO v_reading_id;
    RETURN QUERY SELECT v_reading_id IS NOT NULL, v_reading_id, v_home_id;
END;
$$;

-- Cada id recibe la muestra, pero solo el id principal suma consumo del medidor.
CREATE OR REPLACE FUNCTION device.fn_ingest_sensor_reading(
    p_device_code VARCHAR(100), p_mqtt_message_id VARCHAR(100),
    p_consumption_liters NUMERIC, p_recorded_at TIMESTAMPTZ,
    p_flow_rate_lpm NUMERIC, p_total_liters NUMERIC, p_pulses INTEGER,
    p_sample_interval_seconds NUMERIC, p_wifi_rssi_dbm INTEGER,
    p_signal_quality INTEGER, p_battery_level INTEGER, p_voltage NUMERIC,
    p_temperature NUMERIC, p_hardware_id VARCHAR(32)
)
RETURNS TABLE(inserted BOOLEAN, reading_id UUID, home_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, device, home, consumption, public, pg_temp
AS $$
DECLARE
    v_inserted BOOLEAN;
    v_reading_id UUID;
    v_home_id UUID;
    v_is_primary BOOLEAN := TRUE;
    v_consumption NUMERIC := p_consumption_liters;
BEGIN
    IF p_hardware_id IS NOT NULL
       AND NULLIF(btrim(p_hardware_id), '') IS NOT NULL
       AND btrim(p_hardware_id) !~ '^[A-Za-z0-9_-]{3,32}$' THEN
        RAISE EXCEPTION 'hardwareId no cumple el contrato';
    END IF;

    SELECT gm.is_primary INTO v_is_primary
      FROM device.logical_device_group_member gm
      JOIN device.device d ON d.device_id = gm.device_id
     WHERE d.code = btrim(p_device_code);
    IF FOUND AND NOT v_is_primary THEN v_consumption := 0; END IF;

    SELECT r.inserted, r.reading_id, r.home_id
      INTO v_inserted, v_reading_id, v_home_id
      FROM device.fn_ingest_sensor_reading(
          p_device_code, p_mqtt_message_id, v_consumption, p_recorded_at,
          p_flow_rate_lpm, p_total_liters, p_pulses, p_sample_interval_seconds,
          p_wifi_rssi_dbm, p_signal_quality, p_battery_level, p_voltage, p_temperature
      ) r;

    UPDATE device.device d
       SET hardware_id = COALESCE(NULLIF(btrim(p_hardware_id), ''), d.hardware_id),
           provisioning_status = CASE WHEN d.provisioning_status = 'PENDING' THEN 'MQTT_CONNECTED' ELSE d.provisioning_status END,
           provisioning_updated_at = CASE WHEN NULLIF(btrim(p_hardware_id), '') IS NOT NULL THEN now() ELSE d.provisioning_updated_at END,
           updated_at = now()
     WHERE d.device_id IN (
         SELECT gm.device_id
           FROM device.logical_device_group_member gm
           JOIN device.device member_device ON member_device.device_id = gm.device_id
          WHERE gm.group_key = (
              SELECT gm2.group_key
                FROM device.logical_device_group_member gm2
                JOIN device.device d2 ON d2.device_id = gm2.device_id
               WHERE d2.code = btrim(p_device_code)
          )
     )
        OR d.code = btrim(p_device_code);

    RETURN QUERY SELECT v_inserted, v_reading_id, v_home_id;
END;
$$;

REVOKE ALL ON FUNCTION device.fn_claim_provisioned_device(UUID, VARCHAR) FROM PUBLIC;
REVOKE ALL ON FUNCTION device.fn_switch_device_hardware(UUID, VARCHAR) FROM PUBLIC;
REVOKE ALL ON FUNCTION device.fn_record_device_status(VARCHAR, VARCHAR, TIMESTAMPTZ, VARCHAR, INTEGER, INTEGER, INTEGER, VARCHAR, VARCHAR, VARCHAR) FROM PUBLIC;
REVOKE ALL ON FUNCTION device.fn_record_device_wifi_ssid(VARCHAR, VARCHAR) FROM PUBLIC;
REVOKE ALL ON FUNCTION device.fn_link_device_to_home(VARCHAR, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION device.fn_link_device_to_home_by_hardware(VARCHAR, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION device.fn_ingest_sensor_reading(VARCHAR, VARCHAR, NUMERIC, TIMESTAMPTZ, NUMERIC, NUMERIC, INTEGER, NUMERIC, INTEGER, INTEGER, INTEGER, NUMERIC, NUMERIC, VARCHAR) FROM PUBLIC;
