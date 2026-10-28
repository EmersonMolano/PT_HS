DO $$
BEGIN
    -- Fail safely if one physical board is currently assigned to multiple homes.
    IF EXISTS (
        SELECT gm.group_key
          FROM device.logical_device_group_member gm
          JOIN home.home_device hd
            ON hd.device_id = gm.device_id
           AND hd.status = 'Active'
         GROUP BY gm.group_key
        HAVING COUNT(DISTINCT hd.home_id) > 1
    ) THEN
        RAISE EXCEPTION 'Un grupo ESP32 tiene asociaciones activas con varios hogares; resuelvelas antes de migrar';
    END IF;

    -- Existing links predate logical groups. Copy each single-home assignment
    -- to every active member so the UI and unlink operation see the complete group.
    WITH linked_groups AS (
        SELECT gm.group_key, MIN(hd.home_id::text)::uuid AS home_id
          FROM device.logical_device_group_member gm
          JOIN home.home_device hd
            ON hd.device_id = gm.device_id
           AND hd.status = 'Active'
         GROUP BY gm.group_key
        HAVING COUNT(DISTINCT hd.home_id) = 1
    )
    INSERT INTO home.home_device (home_id, device_id, status, suspended_at)
    SELECT lg.home_id, gm.device_id, 'Active', NULL
      FROM linked_groups lg
      JOIN device.logical_device_group_member gm ON gm.group_key = lg.group_key
      JOIN device.device d ON d.device_id = gm.device_id AND d.status = 'Active'
    ON CONFLICT (home_id, device_id)
    DO UPDATE SET status = 'Active', suspended_at = NULL;
END;
$$;
