-- Fix RLS for owner: allow INSERT into menu_categories for their restaurant only.
-- Run in Supabase Dashboard: SQL Editor → New query → paste → Run.
-- Uses a SECURITY DEFINER function so the policy can reliably check ownership.

-- 1) Helper: true if the given restaurant_id is owned by the current user (or if null, allow for global categories)
CREATE OR REPLACE FUNCTION public.current_user_owns_restaurant(rid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT (rid IS NULL) OR EXISTS (
    SELECT 1 FROM public.restaurants r
    WHERE r.id = rid AND r.owner_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.current_user_owns_restaurant(uuid) TO authenticated;

-- 2) Drop old policy if any
DROP POLICY IF EXISTS "Owner can insert own menu_categories" ON "public"."menu_categories";

-- 3) Owner can insert when restaurant_id is null (global) or they own that restaurant
CREATE POLICY "Owner can insert own menu_categories"
ON "public"."menu_categories"
FOR INSERT
TO authenticated
WITH CHECK (public.current_user_owns_restaurant(menu_categories.restaurant_id));
