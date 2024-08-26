alter table "s-rpc-portfolio-stats".visit
    ADD COLUMN inserted_at timestamp not null default now()
;

