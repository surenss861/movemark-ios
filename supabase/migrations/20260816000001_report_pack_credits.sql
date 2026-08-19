-- Report Pack consumable credits: server is source of truth.
-- RevenueCat NON_RENEWING_PURCHASE / INITIAL_PURCHASE grants +1 (idempotent by event_key).
-- Move-in export enqueue after free quota consumes -1.

CREATE TABLE IF NOT EXISTS public.user_report_credits (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  balance integer NOT NULL DEFAULT 0 CHECK (balance >= 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.report_credit_events (
  event_key text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  delta integer NOT NULL CHECK (delta IN (-1, 1)),
  product_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS report_credit_events_user_id_idx
  ON public.report_credit_events (user_id);

ALTER TABLE public.user_report_credits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_credit_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own report credits" ON public.user_report_credits;
CREATE POLICY "Users can read own report credits"
  ON public.user_report_credits
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can read own report credit events" ON public.report_credit_events;
CREATE POLICY "Users can read own report credit events"
  ON public.report_credit_events
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Grant +1 credit once per RevenueCat event_key. Returns true if newly granted.
CREATE OR REPLACE FUNCTION public.grant_report_credit(
  target_user_id uuid,
  event_key text,
  product_id text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF target_user_id IS NULL OR event_key IS NULL OR length(trim(event_key)) = 0 THEN
    RAISE EXCEPTION 'target_user_id and event_key are required';
  END IF;

  INSERT INTO public.report_credit_events (event_key, user_id, delta, product_id)
  VALUES (event_key, target_user_id, 1, product_id);

  INSERT INTO public.user_report_credits (user_id, balance, updated_at)
  VALUES (target_user_id, 1, now())
  ON CONFLICT (user_id) DO UPDATE
    SET balance = public.user_report_credits.balance + 1,
        updated_at = now();

  RETURN true;
EXCEPTION
  WHEN unique_violation THEN
    RETURN false;
END;
$$;

-- Consume 1 credit once per event_key. Returns true if consumed.
CREATE OR REPLACE FUNCTION public.consume_report_credit(
  target_user_id uuid,
  event_key text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_balance integer;
BEGIN
  IF target_user_id IS NULL OR event_key IS NULL OR length(trim(event_key)) = 0 THEN
    RAISE EXCEPTION 'target_user_id and event_key are required';
  END IF;

  SELECT balance INTO current_balance
  FROM public.user_report_credits
  WHERE user_id = target_user_id
  FOR UPDATE;

  IF current_balance IS NULL OR current_balance < 1 THEN
    RETURN false;
  END IF;

  BEGIN
    INSERT INTO public.report_credit_events (event_key, user_id, delta, product_id)
    VALUES (event_key, target_user_id, -1, NULL);
  EXCEPTION
    WHEN unique_violation THEN
      RETURN false;
  END;

  UPDATE public.user_report_credits
  SET balance = balance - 1,
      updated_at = now()
  WHERE user_id = target_user_id
    AND balance >= 1;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.grant_report_credit(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_report_credit(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.grant_report_credit(uuid, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_report_credit(uuid, text) TO service_role;

-- Keep account deletion complete.
CREATE OR REPLACE FUNCTION public.delete_user_owned_data(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'target_user_id is required';
  END IF;

  DELETE FROM public.report_credit_events
  WHERE user_id = target_user_id;

  DELETE FROM public.user_report_credits
  WHERE user_id = target_user_id;

  DELETE FROM public.user_entitlements
  WHERE user_id = target_user_id;

  DELETE FROM public.dispute_evidence_links
  WHERE dispute_id IN (
    SELECT id FROM public.disputes WHERE user_id = target_user_id
  );

  DELETE FROM public.exports
  WHERE user_id = target_user_id;

  DELETE FROM public.inspection_item_tags
  WHERE inspection_item_id IN (
    SELECT ii.id
    FROM public.inspection_items ii
    INNER JOIN public.inspections i ON i.id = ii.inspection_id
    WHERE i.user_id = target_user_id
  );

  DELETE FROM public.evidence_files
  WHERE property_id IN (
    SELECT id FROM public.properties WHERE user_id = target_user_id
  );

  DELETE FROM public.inspection_items
  WHERE inspection_id IN (
    SELECT id FROM public.inspections WHERE user_id = target_user_id
  );

  DELETE FROM public.inspections
  WHERE user_id = target_user_id;

  DELETE FROM public.maintenance_issues
  WHERE user_id = target_user_id;

  DELETE FROM public.property_documents
  WHERE user_id = target_user_id;

  DELETE FROM public.move_out_checklists
  WHERE user_id = target_user_id;

  DELETE FROM public.move_out_checklist_state
  WHERE user_id = target_user_id;

  DELETE FROM public.disputes
  WHERE user_id = target_user_id;

  DELETE FROM public.rooms
  WHERE property_id IN (
    SELECT id FROM public.properties WHERE user_id = target_user_id
  );

  DELETE FROM public.properties
  WHERE user_id = target_user_id;

  DELETE FROM public.profiles
  WHERE id = target_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user_owned_data(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_owned_data(uuid) TO service_role;
