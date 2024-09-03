create schema "s-rpc-portfolio-stats";

create table "s-rpc-portfolio-stats".visit (
    id UUID NOT NULL DEFAULT uuid_generate_v4(),
    url varchar not null
);

