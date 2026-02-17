-- Fix RLS for users INSERT: allow authenticated user to insert
-- Error 42501: "new row violates row-level security policy"
-- Run in Supabase Dashboard: SQL Editor → New query → paste → Run

DROP POLICY IF EXISTS "Users can insert own row" ON "public"."users";
DROP POLICY IF EXISTS "Allow authenticated insert users" ON "public"."users";

-- Allow authenticated users to INSERT (required when owner saves restaurant before users row exists)
CREATE POLICY "Allow authenticated insert users"
ON "public"."users"
FOR INSERT
TO authenticated
WITH CHECK (true);
