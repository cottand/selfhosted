-- the following does not work on crdb - do the logic manually
IF NOT EXISTS (SELECT 1 FROM pg_index i WHERE indrelid = 'file'::regclass AND indisprimary) THEN
ALTER TABLE file
    ADD PRIMARY KEY (path_hash);
END IF;

-- then mark as completed
INSERT INTO migration_log (migration_id, sql, success, error, timestamp)
VALUES ('add primary key to file table (postgres and sqlite)',
        E'\\n\\t\\tDO $$\\n\\t\\tBEGIN\\n\\t\\t\\t-- Drop the unique constraint if it exists\\n\\t\\t\\tDROP INDEX IF EXISTS "UQE_file_path_hash";\\n\\n\\t\\t\\t-- Add primary key if it doesn\'t already exist\\n\\t\\t\\tIF NOT EXISTS (SELECT 1 FROM pg_index i WHERE indrelid = \'\'file\'\'::regclass AND indisprimary) THEN\\n\\t\\t\\t\\tALTER TABLE file ADD PRIMARY KEY (path_hash);\\n\\t\\t\\tEND IF;\\n\\t\\tEND $$;\\n\\t',
        true,
        '',
        current_timestamp);

-- Drop the unique constraint if it exists
DROP INDEX IF EXISTS "UQE_file_meta_path_hash_key";

-- Add primary key if it doesn't already exist
IF NOT EXISTS (SELECT 1 FROM pg_index i WHERE indrelid = 'file_meta'::regclass AND indisprimary) THEN
ALTER TABLE file_meta
    ADD PRIMARY KEY (path_hash, ` + "`key`" + `);

INSERT INTO migration_log (migration_id, sql, success, error, timestamp)
VALUES ('create cloud_migration_snapshot_partition table v1',
        'select 1;',
        true,
        '',
        current_timestamp);



SELECT *
from migration_log
where migration_id = 'add primary key to file table (postgres and sqlite)';

DELETE
FROM migration_log
where migration_id = 'add primary key to file table (postgres and sqlite)';

select *
from migration_log where migration_id = 'add primary key to file_meta table (postgres and sqlite)';