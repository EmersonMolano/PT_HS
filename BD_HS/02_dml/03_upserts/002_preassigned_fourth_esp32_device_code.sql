-- En esta placa el identificador fisico tambien se ofrece como cuarto codigo
-- logico seleccionable; hardware_id sigue representando la identidad eFuse.
INSERT INTO device.device (
    code,
    name,
    type,
    status,
    provisioning_status
)
VALUES
    ('HS-141F47470968', 'ESP32 HidroSmart 04', 'water_sensor', 'Active', 'PENDING')
ON CONFLICT (code) DO NOTHING;
