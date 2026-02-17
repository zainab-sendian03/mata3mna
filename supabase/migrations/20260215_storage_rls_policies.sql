-- Supabase Storage RLS policies for bucket "mata3mna"
-- Allows authenticated users (owners and admins) to upload, read, update, delete files
-- Run in Supabase Dashboard: SQL Editor → New query → paste → Run
--
-- Ensure the bucket "mata3mna" exists in Storage (create via Dashboard if needed)

-- Drop existing policies (if re-running)
DROP POLICY IF EXISTS "Allow authenticated insert storage mata3mna" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated select storage mata3mna" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated update storage mata3mna" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated delete storage mata3mna" ON storage.objects;

-- 1. INSERT: Allow authenticated users to upload files
CREATE POLICY "Allow authenticated insert storage mata3mna"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'mata3mna');

-- 2. SELECT: Allow authenticated users to read files
CREATE POLICY "Allow authenticated select storage mata3mna"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'mata3mna');

-- 3. UPDATE: Allow authenticated users to update (overwrite) files
CREATE POLICY "Allow authenticated update storage mata3mna"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'mata3mna')
WITH CHECK (bucket_id = 'mata3mna');

-- 4. DELETE: Allow authenticated users to delete files
CREATE POLICY "Allow authenticated delete storage mata3mna"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'mata3mna');
