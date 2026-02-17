-- Auto-create public.users row when auth.users has new signup
-- Runs with SECURITY DEFINER so RLS doesn't block
-- Run in Supabase Dashboard: SQL Editor → New query → paste → Run

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.users (id, email, role, password, created_at, updated_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    'owner',
    'supabase_auth',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();
