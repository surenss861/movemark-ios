-- Owner-path gate for a REAL Neon branch (runs as neondb_owner, rolls back; leaves no data).
--   psql "$DEV_DSN" -v ON_ERROR_STOP=1 -f neon/tests/neon_owner_gate.sql
-- Covers what does not need a client JWT. Client RLS is covered by test_reconstruction.py
-- locally and by the Data API end-to-end check.
BEGIN;
DO $t$
DECLARE a uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'; b uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  pa uuid; pb uuid; r uuid; i uuid; it uuid; ok boolean; n int; claimed int;
BEGIN
  SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace WHERE s.nspname='public' AND c.relkind='r' AND NOT c.relrowsecurity;
  IF n<>0 THEN RAISE EXCEPTION 'FAIL rls missing on % tables', n; END IF; RAISE NOTICE 'ok  every public table has RLS';
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace JOIN pg_depend d ON d.objid=p.oid AND d.deptype='e' WHERE s.nspname='public';
  IF n<>0 THEN RAISE EXCEPTION 'FAIL % extension functions in public', n; END IF; RAISE NOTICE 'ok  no extension functions exposed in public';
  SELECT count(*) INTO n FROM issue_tags; IF n<6 THEN RAISE EXCEPTION 'FAIL tags %', n; END IF; RAISE NOTICE 'ok  issue tags seeded (%)', n;
  SELECT count(*) INTO n FROM information_schema.role_routine_grants WHERE routine_schema='public' AND grantee IN ('authenticated','anonymous','PUBLIC') AND routine_name <> 'get_property_snapshot';
  IF n<>0 THEN RAISE EXCEPTION 'FAIL % non-snapshot functions callable by clients', n; END IF; RAISE NOTICE 'ok  only get_property_snapshot is client-callable';
  INSERT INTO neon_auth."user"(id,email,name,"emailVerified","createdAt","updatedAt") VALUES (a,'a@qa.invalid','A',false,now(),now()),(b,'b@qa.invalid','B',false,now(),now());
  INSERT INTO properties(user_id,title,address_line_1,city,province_state,postal_code,country) VALUES (a,'QA','1','c','p','z','x') RETURNING id INTO pa;
  INSERT INTO properties(user_id,title,address_line_1,city,province_state,postal_code,country) VALUES (b,'QA','1','c','p','z','x') RETURNING id INTO pb;
  INSERT INTO rooms(property_id,name) VALUES (pa,'Kitchen') RETURNING id INTO r;
  INSERT INTO inspections(property_id,user_id,inspection_type) VALUES (pa,a,'move_in') RETURNING id INTO i;
  INSERT INTO inspection_items(inspection_id,room_id) VALUES (i,r) RETURNING id INTO it;
  INSERT INTO evidence_files(property_id,inspection_item_id,file_path,file_type) VALUES (pa,it,'p','image');
  BEGIN INSERT INTO evidence_files(property_id,file_path,file_type) VALUES (pa,'p','image'); RAISE EXCEPTION 'FAIL evidence without parent accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'ok  evidence must have exactly one parent'; END;
  BEGIN INSERT INTO inspections(property_id,user_id,inspection_type) VALUES (pa,a,'move_in'); RAISE EXCEPTION 'FAIL duplicate inspection';
  EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok  one inspection per property/user/type'; END;
  PERFORM grant_report_credit(a,'rc:1','pack'); PERFORM grant_report_credit(a,'rc:1','pack');
  SELECT balance INTO n FROM user_report_credits WHERE user_id=a; IF n<>1 THEN RAISE EXCEPTION 'FAIL grant not idempotent (%)', n; END IF;
  SELECT consume_report_credit(a,'e:1') INTO ok; IF NOT ok THEN RAISE EXCEPTION 'FAIL consume'; END IF;
  SELECT consume_report_credit(a,'e:2') INTO ok; IF ok THEN RAISE EXCEPTION 'FAIL consumed below zero'; END IF;
  RAISE NOTICE 'ok  credits idempotent, never negative';
  INSERT INTO exports(user_id,property_id,export_type,status) VALUES (a,pa,'move_in_report','queued');
  BEGIN INSERT INTO exports(user_id,property_id,export_type,status) VALUES (a,pa,'move_in_report','queued'); RAISE EXCEPTION 'FAIL two active jobs';
  EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok  one active export job per property/type (23505)'; END;
  SELECT count(*) INTO claimed FROM claim_next_export_job(); IF claimed<>1 THEN RAISE EXCEPTION 'FAIL claim %', claimed; END IF;
  RAISE NOTICE 'ok  claim_next_export_job claims one job';
  PERFORM delete_user_owned_data(a);
  SELECT (SELECT count(*) FROM properties WHERE user_id=a)+(SELECT count(*) FROM exports WHERE user_id=a)+(SELECT count(*) FROM user_report_credits WHERE user_id=a)+(SELECT count(*) FROM inspections WHERE user_id=a) INTO n;
  IF n<>0 THEN RAISE EXCEPTION 'FAIL deletion left % rows', n; END IF;
  SELECT count(*) INTO n FROM properties WHERE user_id=b; IF n<>1 THEN RAISE EXCEPTION 'FAIL deletion touched other user'; END IF;
  DELETE FROM neon_auth."user" WHERE id=a;
  RAISE NOTICE 'ok  delete_user_owned_data removes only that user; auth user then deletable';
END $t$;
ROLLBACK;
