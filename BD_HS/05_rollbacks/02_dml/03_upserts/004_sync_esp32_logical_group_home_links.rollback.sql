-- Intentionally retain reconciled home-device links on rollback. They are
-- valid associations and deleting them could silently disconnect user devices.
SELECT 1;
