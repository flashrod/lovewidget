-- ============================================================
-- LoveWidget — Row Level Security Policies
-- Migration: 002_rls_policies.sql
-- Apply AFTER 001_initial_schema.sql
-- ============================================================

-- ============================================================
-- USERS TABLE: RLS
-- ============================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Users can read their own record
CREATE POLICY "users_select_own"
    ON public.users
    FOR SELECT
    USING (auth.uid() = id);

-- Users can read their partner's name/id (needed for UI display)
CREATE POLICY "users_select_partner"
    ON public.users
    FOR SELECT
    USING (
        id IN (
            SELECT user_one FROM public.pairs WHERE user_two = auth.uid()
            UNION
            SELECT user_two FROM public.pairs WHERE user_one = auth.uid()
        )
    );

-- Users can only create their own record (id must equal auth.uid())
CREATE POLICY "users_insert_own"
    ON public.users
    FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Users can only update their own record
CREATE POLICY "users_update_own"
    ON public.users
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- ============================================================
-- PAIRS TABLE: RLS
-- ============================================================
ALTER TABLE public.pairs ENABLE ROW LEVEL SECURITY;

-- A user can read a pair if they are user_one or user_two
CREATE POLICY "pairs_select_member"
    ON public.pairs
    FOR SELECT
    USING (
        auth.uid() = user_one OR auth.uid() = user_two
    );

-- Any authenticated user can read an incomplete pair by invite code
-- (needed to validate the code before joining)
CREATE POLICY "pairs_select_by_invite_code"
    ON public.pairs
    FOR SELECT
    USING (
        user_two IS NULL
        AND auth.uid() IS NOT NULL
    );

-- Only user_one can create a pair (they own it)
CREATE POLICY "pairs_insert_user_one"
    ON public.pairs
    FOR INSERT
    WITH CHECK (auth.uid() = user_one AND user_two IS NULL);

-- The join_pair() SECURITY DEFINER function handles the user_two update,
-- so no UPDATE policy is needed here for regular users.

-- ============================================================
-- DRAWINGS TABLE: RLS
-- ============================================================
ALTER TABLE public.drawings ENABLE ROW LEVEL SECURITY;

-- A user can read a drawing if they are in the pair
CREATE POLICY "drawings_select_pair_member"
    ON public.drawings
    FOR SELECT
    USING (
        pair_id IN (
            SELECT id FROM public.pairs
            WHERE user_one = auth.uid() OR user_two = auth.uid()
        )
    );

-- A user can insert a drawing for their pair
CREATE POLICY "drawings_insert_pair_member"
    ON public.drawings
    FOR INSERT
    WITH CHECK (
        pair_id IN (
            SELECT id FROM public.pairs
            WHERE user_one = auth.uid() OR user_two = auth.uid()
        )
        AND created_by = auth.uid()
    );

-- A user can update any drawing in their pair
-- (both users can draw — no "owner" restriction)
CREATE POLICY "drawings_update_pair_member"
    ON public.drawings
    FOR UPDATE
    USING (
        pair_id IN (
            SELECT id FROM public.pairs
            WHERE user_one = auth.uid() OR user_two = auth.uid()
        )
    )
    WITH CHECK (
        created_by = auth.uid()
    );

-- ============================================================
-- REALTIME: Enable broadcast for drawings table
-- ============================================================
-- Allow the drawings table to publish change events via Supabase Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.drawings;

-- ============================================================
-- GRANT: Ensure the anon role can use the join_pair function
-- ============================================================
GRANT EXECUTE ON FUNCTION join_pair(TEXT, UUID) TO authenticated, anon;
