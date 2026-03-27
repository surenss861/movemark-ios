-- MoveMark production: exactly one reference per dispute_evidence_links row

ALTER TABLE public.dispute_evidence_links
  DROP CONSTRAINT IF EXISTS dispute_evidence_links_exactly_one_ref_check;

ALTER TABLE public.dispute_evidence_links
  ADD CONSTRAINT dispute_evidence_links_exactly_one_ref_check
  CHECK (
    (
      (CASE WHEN evidence_file_id IS NOT NULL THEN 1 ELSE 0 END) +
      (CASE WHEN maintenance_issue_id IS NOT NULL THEN 1 ELSE 0 END) +
      (CASE WHEN property_document_id IS NOT NULL THEN 1 ELSE 0 END)
    ) = 1
  );
