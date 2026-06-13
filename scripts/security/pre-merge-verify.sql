-- MoveMark security pre-merge verification
-- Run in Supabase SQL Editor (live production project) before merging movemark-security-hardening.

-- Step 1: Apply export status constraint (export v2 compatible)
ALTER TABLE public.exports DROP CONSTRAINT IF EXISTS exports_status_allowed;
ALTER TABLE public.exports DROP CONSTRAINT IF EXISTS exports_status_check;

ALTER TABLE public.exports ADD CONSTRAINT exports_status_check
  CHECK (status IN ('queued', 'processing', 'verifying', 'completed', 'failed'));

-- Step 1 verify: must include 'verifying'
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.exports'::regclass
  AND conname = 'exports_status_check';

-- Step 2 verify: RLS enabled on sensitive tables
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles',
    'properties',
    'rooms',
    'inspections',
    'evidence_files',
    'property_documents',
    'exports'
  )
ORDER BY tablename;

-- Expected: every row shows rowsecurity = true

-- Step 3: RLS policies exist (rowsecurity alone is not enough)
SELECT schemaname, tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles',
    'properties',
    'rooms',
    'inspections',
    'evidence_files',
    'property_documents',
    'exports'
  )
ORDER BY tablename, policyname;

-- Step 3 summary: each sensitive table should have at least one policy
SELECT tablename, COUNT(*) AS policy_count
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles',
    'properties',
    'rooms',
    'inspections',
    'evidence_files',
    'property_documents',
    'exports'
  )
GROUP BY tablename
ORDER BY tablename;

-- Expected: policy_count >= 1 on every table above.
-- Final proof: two-account test in docs/SECURITY_QA.md (Account B cannot read A's rows).
