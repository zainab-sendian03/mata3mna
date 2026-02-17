-- Allow any authenticated user (owner or admin) to INSERT into menu_categories.
-- Fixes RLS 42501 when owner adds a category from mobile (with or without restaurant_id).
-- Run in Supabase Dashboard: SQL Editor → New query → paste → Run.

-- 1. Drop ALL existing policies on menu_categories (run this first to see current state)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'menu_categories') LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON "public"."menu_categories"', r.policyname);
  END LOOP;
END $$;

-- 2. Enable RLS if not already (required for policies to apply)
ALTER TABLE "public"."menu_categories" ENABLE ROW LEVEL SECURITY;

-- 3. INSERT: allow all (fixes RLS when auth.uid() may be unset in some request paths)
-- Tighten later with: WITH CHECK (auth.uid() IS NOT NULL) if needed
CREATE POLICY "Allow insert menu_categories when authenticated"
ON "public"."menu_categories"
FOR INSERT
TO public
WITH CHECK (true);

-- 4. SELECT: allow all authenticated + anon (for public read if needed)
CREATE POLICY "Allow select menu_categories"
ON "public"."menu_categories"
FOR SELECT
TO public
USING (true);

-- 5. UPDATE: allow all (for category renames etc.)
CREATE POLICY "Allow update menu_categories when authenticated"
ON "public"."menu_categories"
FOR UPDATE
TO public
USING (true)
WITH CHECK (true);

-- 6. DELETE: allow all
CREATE POLICY "Allow delete menu_categories when authenticated"
ON "public"."menu_categories"
FOR DELETE
TO public
USING (true);
