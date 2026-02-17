-- Allow admin to insert restaurants (and ensure users table is readable for the policy check).
-- Run in Supabase Dashboard: SQL Editor → New query → paste → Run.
-- If you get "policy already exists" on one statement, skip it and run the other.

-- 1) So the restaurants policy can read users.role, allow each user to read their own row in users.
CREATE POLICY "Users can read own row"
ON "public"."users"
FOR SELECT
TO authenticated
USING (id = auth.uid());

-- 2) Allow authenticated users with role 'admin' to INSERT into restaurants.
CREATE POLICY "Allow admin to insert restaurants"
ON "public"."restaurants"
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = auth.uid()
    AND users.role = 'admin'
  )
);
