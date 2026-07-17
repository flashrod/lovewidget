-- ============================================================
-- LoveWidget — DELETE Policy for Pairs
-- Migration: 003_delete_policy.sql
-- Apply AFTER 001_initial_schema.sql and 002_rls_policies.sql
-- ============================================================

-- Allow either member of a pair to delete (reset) it
CREATE POLICY "pairs_delete_member"
    ON public.pairs
    FOR DELETE
    USING (
        auth.uid() = user_one OR auth.uid() = user_two
    );

-- Also allow deleting drawings when the pair is deleted (cascade)
-- (this is handled by ON DELETE CASCADE on the foreign key, no policy needed)
