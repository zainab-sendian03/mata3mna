-- Set a user as admin so RLS allows them to insert/update restaurants.
-- Run in Supabase SQL Editor. Replace YOUR_AUTH_USER_UUID with the id from:
--   Dashboard → Authentication → Users (copy the UUID of your admin account)
-- Or use the "Current user" id printed in the app when the RLS error appears.

-- Step 1: Check current value (run this first to see what's in the row)
-- SELECT id, email, role FROM public.users WHERE id = '3d7dd86c-055b-48e3-a475-b6c9d1587291';

-- Step 2: Force role to admin for the dashboard login user
UPDATE public.users
SET role = 'admin'
WHERE id = '3d7dd86c-055b-48e3-a475-b6c9d1587291';

-- Step 3: Verify (run after UPDATE — should show role = admin)
-- SELECT id, email, role FROM public.users WHERE id = '3d7dd86c-055b-48e3-a475-b6c9d1587291';

-- If your id is different, use:
-- UPDATE public.users SET role = 'admin' WHERE id = 'YOUR_AUTH_USER_UUID';
