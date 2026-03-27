-- Seed issue_tags for Room Detail fixed tag picker. Safe to re-run (skips existing names).
INSERT INTO public.issue_tags (id, name)
SELECT gen_random_uuid(), v
FROM (VALUES
  ('Scratch'),
  ('Stain'),
  ('Water damage'),
  ('Chipped paint'),
  ('Cracked tile'),
  ('Appliance damage'),
  ('Scuff marks'),
  ('Loose fixture')
) AS t(v)
WHERE NOT EXISTS (SELECT 1 FROM public.issue_tags WHERE name = t.v);
