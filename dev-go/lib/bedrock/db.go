package bedrock

import (
	"database/sql"
	"embed"
	"errors"
	"log/slog"
	"os"

	"github.com/XSAM/otelsql"
	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/cockroachdb"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/monzo/terrors"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

// Migrate expects the first argument to have a folder called 'migrations'
func Migrate(db *sql.DB, serviceName string, migrations embed.FS) error {
	dbname := serviceName
	errParams := map[string]string{"db": dbname}

	driver, err := cockroachdb.WithInstance(db, &cockroachdb.Config{DatabaseName: dbname})
	if err != nil {
		return terrors.Augment(err, "failed to create migration instance client", errParams)
	}
	sourceDriver, err := iofs.New(migrations, "db-migrations")
	if err != nil {
		return terrors.Augment(err, "failed to open db migrations embedded fs", errParams)
	}
	m, err := migrate.NewWithInstance("migrations", sourceDriver, dbname, driver)
	if err != nil {
		return terrors.Augment(err, "failed to init db migration client", errParams)
	}
	slog.Info("applying DB migrations...", "db", dbname)
	err = m.Up()
	if err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return terrors.Augment(err, "failed to apply migrations", errParams)
	}
	if err != nil {
		slog.Info("no DB migrations to apply", "db", dbname)
		return nil
	}
	slog.Info("db migrations applied successfully", "db", dbname)
	return nil
}

// OpenDB expects the caller to close the sql.DB returned
func OpenDB() (*sql.DB, error) {
	url, ok := os.LookupEnv("CRDB_CONN_URL")
	if !ok {
		return nil, errors.New("CRDB_CONN_URL environment variable not set")
	}
	db, err := otelsql.Open("pgx", url, otelsql.WithAttributes(semconv.DBSystemCockroachdb))
	return db, terrors.Augment(err, "failed to start db client", nil)
}

func migrateDB(migrations embed.FS) error {
	db, err := OpenDB()
	if err != nil {
		return terrors.Propagate(err)
	}
	defer db.Close()
	err = Migrate(db, "main", migrations)
	return terrors.Augment(err, "failed to migrate database", nil)
}
