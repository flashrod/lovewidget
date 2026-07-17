-- ============================================================
-- LoveWidget — SECURITY DEFINER upsert for users table
-- Migration: 004_upsert_user_function.sql
-- Apply AFTER 002_rls_policies.sql
-- ============================================================
--
-- RLS on the users table prevents a returning anonymous session
-- from updating its stale row (different auth.uid(), same device_id).
-- This SECURITY DEFINER function bypasses RLS for the upsert while
-- keeping the underlying table protected from direct modification.
--
-- Usage: SELECT upsert_user(
--   p_id        := '<auth_uid>',
--   p_name      := '<display_name>',
--   p_device_id := '<hardware_uuid>'
-- );

CREATE OR REPLACE FUNCTION public.upsert_user(
    p_id UUID,
    p_name TEXT,
    p_device_id TEXT
)
RETURNS SETOF public.users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO public.users (id, name, device_id)
    VALUES (p_id, p_name, p_device_id)
    ON CONFLICT (device_id)
    DO UPDATE SET
        id   = EXCLUDED.id,
        name = EXCLUDED.name
    RETURNING *;
END;
$$;

-- Grant execution to authenticated and anon roles
GRANT EXECUTE ON FUNCTION public.upsert_user(UUID, TEXT, TEXT) TO authenticated, anon;
