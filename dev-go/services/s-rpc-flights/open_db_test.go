package module

import (
	"github.com/golang-migrate/migrate/v4/source/iofs"
	"testing"
)

func TestCanOpenEmbedded(t *testing.T) {
	_, err := iofs.New(dbMigrations, "migrations")
	if err != nil {
		t.Fatalf("failed to open embedded migrations: %v", err)
	}
}
