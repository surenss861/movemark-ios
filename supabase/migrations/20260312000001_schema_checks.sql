-- MoveMark production: constrain enum-like text fields
-- Run after existing schema. Fix any existing invalid data before running.

-- inspections
ALTER TABLE public.inspections
  ADD CONSTRAINT inspections_type_check
  CHECK (inspection_type IN ('move_in', 'move_out'));

ALTER TABLE public.inspections
  ADD CONSTRAINT inspections_status_check
  CHECK (status IN ('in_progress', 'completed'));

-- maintenance_issues
ALTER TABLE public.maintenance_issues
  ADD CONSTRAINT maintenance_status_check
  CHECK (status IN ('open', 'follow_up', 'resolved'));

-- property_documents
ALTER TABLE public.property_documents
  ADD CONSTRAINT property_documents_type_check
  CHECK (document_type IN (
    'lease',
    'deposit_receipt',
    'listing_screenshot',
    'cleaning_receipt',
    'utility_record',
    'move_out_invoice',
    'other'
  ));

-- disputes
ALTER TABLE public.disputes
  ADD CONSTRAINT disputes_type_check
  CHECK (dispute_type IN (
    'deposit_withheld',
    'damage_charge',
    'cleaning_fee',
    'itemized_deductions',
    'other'
  ));

ALTER TABLE public.disputes
  ADD CONSTRAINT disputes_status_check
  CHECK (status IN (
    'draft',
    'reviewing',
    'packet_generated',
    'sent',
    'closed'
  ));

-- exports (type only here; status/columns in next migration)
ALTER TABLE public.exports
  ADD CONSTRAINT exports_type_check
  CHECK (export_type IN (
    'move_in_report',
    'move_out_report',
    'dispute_packet',
    'summary_pdf'
  ));
