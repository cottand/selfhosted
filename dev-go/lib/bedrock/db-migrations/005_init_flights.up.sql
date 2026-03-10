create schema "s-rpc-flights";

create table "s-rpc-flights".flight
(
    id             UUID      NOT NULL DEFAULT uuid_generate_v4(),
    airline_code   varchar   not null,
    flight_number  varchar   not null,
    src_airport    varchar   not null,
    dst_airport    varchar   not null,

    departure_date date      not null,

    created_at     timestamp not null default now(),
    PRIMARY KEY (id)
);

