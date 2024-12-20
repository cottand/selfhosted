create user if not exists attic;

create database if not exists attic;

grant all on database attic to attic;

alter user attic with password '_';

ALTER DATABASE attic SET default_transaction_isolation = 'read committed';

delete from chunkref;
delete from nar;
delete from chunk;
delete from object;
