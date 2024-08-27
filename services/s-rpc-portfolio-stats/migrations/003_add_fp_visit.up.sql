alter table "s-rpc-portfolio-stats".visit
    -- biging is 64bit in CRDB!
    ADD COLUMN fingerprint_v1 bigint not null default -1
;

