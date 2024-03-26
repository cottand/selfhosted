create user if not exists grafana;

drop table if exists grafana;
create database if not exists grafana;

grant ALL on database grafana to grafana;

SET CLUSTER SETTING sql.defaults.experimental_alter_column_type.enabled to true;

-- -- was needed for grafana migration
-- -- ALTER TABLE "dashboard" ALTER "title" TYPE VARCHAR(189);
-- ALTER TABLE "file" ALTER COLUMN path TYPE VARCHAR(1024) COLLATE "C";
