-- movemark-api queues exports before PDF upload; file_path is set on completion.
ALTER TABLE public.exports
  ALTER COLUMN file_path DROP NOT NULL;
