create user if not exists seaweed_filer;

create database if not exists seaweed_filer;

grant ALL on database seaweed_filer to seaweed_filer;

alter user seaweed_filer with password '_';

-- -- was needed for grafana migration
-- -- ALTER TABLE "dashboard" ALTER "title" TYPE VARCHAR(189);
-- ALTER TABLE "file" ALTER COLUMN path TYPE VARCHAR(1024) COLLATE "C";
