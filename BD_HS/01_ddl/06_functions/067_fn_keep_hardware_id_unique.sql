-- Un estado MQTT retrasado del codigo anterior no debe volver a asociar la
-- placa despues de que el usuario haya cambiado al codigo logico nuevo.
CREATE OR REPLACE FUNCTION device.fn_keep_hardware_id_unique()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, device, public, pg_temp
AS $$
BEGIN
    IF NEW.hardware_id IS NULL OR btrim(NEW.hardware_id) = '' THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1
          FROM device.device d
         WHERE d.hardware_id = NEW.hardware_id
           AND d.device_id <> NEW.device_id
    ) THEN
        IF TG_OP = 'UPDATE' THEN
            NEW.hardware_id := OLD.hardware_id;
        ELSE
            RAISE EXCEPTION 'hardwareId ya esta asociado a otro dispositivo'
                USING ERRCODE = '23505';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER tr_device_hardware_id_unique
BEFORE INSERT OR UPDATE OF hardware_id ON device.device
FOR EACH ROW
EXECUTE FUNCTION device.fn_keep_hardware_id_unique();

COMMENT ON FUNCTION device.fn_keep_hardware_id_unique() IS
'Evita que un estado MQTT retrasado reasigne una placa fisica a su codigo logico anterior.';
