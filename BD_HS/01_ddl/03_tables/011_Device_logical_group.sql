-- Agrupa varios codigos logicos que representan una unica placa fisica.
CREATE TABLE device.logical_device_group_member (
    device_id UUID PRIMARY KEY REFERENCES device.device(device_id) ON DELETE CASCADE,
    group_key VARCHAR(64) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_logical_device_group_key CHECK (btrim(group_key) <> '')
);

CREATE INDEX idx_logical_device_group_member_group
    ON device.logical_device_group_member(group_key, device_id);

CREATE UNIQUE INDEX uq_logical_device_group_primary
    ON device.logical_device_group_member(group_key)
    WHERE is_primary;

COMMENT ON TABLE device.logical_device_group_member IS
'Relaciona codigos logicos que comparten una placa ESP32 fisica; el miembro principal contabiliza el consumo.';
