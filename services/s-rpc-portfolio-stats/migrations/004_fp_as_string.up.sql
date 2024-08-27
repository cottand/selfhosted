alter table "s-rpc-portfolio-stats".visit
    -- biging is 64bit in CRDB!
    DROP COLUMN fingerprint_v1
;

alter table "s-rpc-portfolio-stats".visit
    add column fingerprint_v1 bigint not null default -1
;

