CREATE OR REPLACE FUNCTION alert_rate.fn_get_home_pending_alerts(
    p_home_id UUID
)
RETURNS TABLE (
    home_id UUID,
    pending_count BIGINT,
    last_alert_at TIMESTAMPTZ,
    refreshed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = alert_rate, home, user_account, public, pg_temp
AS $$
BEGIN
    IF NOT user_account.fn_app_has_permission('alerts.manage')
       OR NOT home.fn_is_home_member(p_home_id, user_account.fn_app_current_user_id()) THEN
        RAISE EXCEPTION 'La cuenta no puede consultar las alertas de este hogar';
    END IF;

    RETURN QUERY
    SELECT mv.home_id, mv.pending_count, mv.last_alert_at, mv.refreshed_at
      FROM alert_rate.mv_pending_alerts mv
     WHERE mv.home_id = p_home_id;
END;
$$;
