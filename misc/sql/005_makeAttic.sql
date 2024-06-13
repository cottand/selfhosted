create user if not exists attic;

create database if not exists attic;

grant all on database attic to attic;

alter user attic with password '_';
