-- RLS policies: allow authenticated owners to CRUD their menu items and edit their info.
-- Run in Supabase Dashboard: SQL Editor → New query → paste → Run.
-- If any policy already exists, you will get "already exists" — skip that statement or drop it first.
--
-- Ensure RLS is enabled on the tables (Supabase often enables it by default):
--   ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
--   ALTER TABLE public.restaurants ENABLE ROW LEVEL SECURITY;
--   ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;
--   ALTER TABLE public.menu_categories ENABLE ROW LEVEL SECURITY;

-- ========== 1) USERS: owner can update own row (edit profile) ==========
-- SELECT already allowed by "Users can read own row". Add UPDATE for own row.
CREATE POLICY "Users can update own row"
ON "public"."users"
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- ========== 2) RESTAURANTS: owner can SELECT/UPDATE/INSERT own restaurant(s) ==========
-- Owner can read their restaurant (by owner_id)
CREATE POLICY "Owner can read own restaurant"
ON "public"."restaurants"
FOR SELECT
TO authenticated
USING (
  owner_id = auth.uid()
);

-- Owner can update their restaurant (e.g. edit info from mobile)
CREATE POLICY "Owner can update own restaurant"
ON "public"."restaurants"
FOR UPDATE
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

-- Owner can insert a restaurant when creating from mobile (complete restaurant info)
CREATE POLICY "Owner can insert own restaurant"
ON "public"."restaurants"
FOR INSERT
TO authenticated
WITH CHECK (owner_id = auth.uid());

-- ========== 3) MENU_ITEMS: owner can CRUD items for their restaurant only ==========
-- Owner can SELECT menu items that belong to their restaurant
CREATE POLICY "Owner can read own menu items"
ON "public"."menu_items"
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.restaurants r
    WHERE r.id = menu_items.restaurant_id
    AND r.owner_id = auth.uid()
  )
);

-- Owner can INSERT menu items only for their restaurant
CREATE POLICY "Owner can insert own menu items"
ON "public"."menu_items"
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.restaurants r
    WHERE r.id = menu_items.restaurant_id
    AND r.owner_id = auth.uid()
  )
);

-- Owner can UPDATE menu items only for their restaurant
CREATE POLICY "Owner can update own menu items"
ON "public"."menu_items"
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.restaurants r
    WHERE r.id = menu_items.restaurant_id
    AND r.owner_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.restaurants r
    WHERE r.id = menu_items.restaurant_id
    AND r.owner_id = auth.uid()
  )
);

-- Owner can DELETE menu items only for their restaurant
CREATE POLICY "Owner can delete own menu items"
ON "public"."menu_items"
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.restaurants r
    WHERE r.id = menu_items.restaurant_id
    AND r.owner_id = auth.uid()
  )
);

-- ========== 4) MENU_CATEGORIES: owner needs to read and create categories (e.g. "غير مصنف") ==========
-- Allow authenticated users (including owners) to read menu_categories
CREATE POLICY "Authenticated can read menu_categories"
ON "public"."menu_categories"
FOR SELECT
TO authenticated
USING (true);

-- Owner can insert a category only when restaurant_id belongs to their restaurant
CREATE POLICY "Owner can insert own menu_categories"
ON "public"."menu_categories"
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() IN (
    SELECT r.owner_id FROM public.restaurants r
    WHERE r.id = menu_categories.restaurant_id
  )
);
