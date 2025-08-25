create user if not exists ente;

drop table if exists ente;
create database if not exists ente;

grant ALL on database ente to ente;

SET CLUSTER SETTING sql.defaults.experimental_alter_column_type.enabled to true;

