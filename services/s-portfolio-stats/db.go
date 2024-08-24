package main

import (
	"database/sql"
	"errors"
	"github.com/XSAM/otelsql"
	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/cockroachdb"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/monzo/terrors"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	"os"

	_ "github.com/golang-migrate/migrate/v4/database/cockroachdb"
)

func Migrate(db *sql.DB, dbname string) error {
	driver, err := cockroachdb.WithInstance(db, &cockroachdb.Config{DatabaseName: dbname})
	if err != nil {
		return terrors.Augment(err, "failed to run db migrations", map[string]string{"db": dbname})
	}
	m, err := migrate.NewWithDatabaseInstance(
		"TODO",
		"cockroachdb", driver)
	return m.Up()
}

func GetDb() (*sql.DB, error) {
	url, ok := os.LookupEnv("CRDB_CONN_URL")
	if !ok {
		return nil, errors.New("CRDB_CONN_URL environment variable not set")
	}
	db, err := otelsql.Open("pgx", url, otelsql.WithAttributes(semconv.DBSystemCockroachdb))
	// TODO MIGRATE
	return db, terrors.Propagate(err)
}
