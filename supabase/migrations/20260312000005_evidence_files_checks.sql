-- MoveMark production: evidence_files exactly one parent + file_type constraint

ALTER TABLE public.evidence_files
  DROP CONSTRAINT IF EXISTS evidence_files_exactly_one_parent_check;

ALTER TABLE public.evidence_files
  ADD CONSTRAINT evidence_files_exactly_one_parent_check
  CHECK (
    (
      (CASE WHEN inspection_item_id IS NOT NULL THEN 1 ELSE 0 END) +
      (CASE WHEN maintenance_issue_id IS NOT NULL THEN 1 ELSE 0 END)
    ) = 1
  );

ALTER TABLE public.evidence_files
  DROP CONSTRAINT IF EXISTS evidence_files_type_check;

ALTER TABLE public.evidence_files
  ADD CONSTRAINT evidence_files_type_check
  CHECK (file_type IN ('image', 'pdf', 'video'));
