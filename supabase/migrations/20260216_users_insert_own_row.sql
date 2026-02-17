-- Allow authenticated users to INSERT their own row in users table
-- Required when owner saves restaurant info before users row exists (e.g. signup flow gap)
-- Run in Supabase Dashboard: SQL Editor → New query → paste → Run

DROP POLICY IF EXISTS "Users can insert own row" ON "public"."users";

CREATE POLICY "Users can insert own row"
ON "public"."users"
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());
