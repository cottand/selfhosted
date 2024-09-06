package module

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/monzo/terrors"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"time"
)

var (
	refreshRate = 30 * time.Second
	//uniqueVisitInterval = 1 * time.Hour

	visits = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: bedrock.KebabToSnakeCase(Name),
		Name:      "page_visits",
		Help:      "Page visits to web_portfolio",
	}, []string{"since"})

	visitsUnique = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: bedrock.KebabToSnakeCase(Name),
		Name:      "page_visits_unique",
		Help:      "Unique page visits to web_portfolio",
	}, []string{"since"})
)

// RefreshPromStats returns when ctx is cancelled or done
func RefreshPromStats(ctx context.Context, db *sql.DB) {
	day := 24 * time.Hour
	for {
		accumulatedErr := errors.Join(
			refreshPageVisitsSince(ctx, db, 0),
			refreshPageVisitsSince(ctx, db, day),
			refreshPageVisitsSince(ctx, db, 7*day),
			refreshPageVisitsSince(ctx, db, 30*day),
			refreshPageVisitsSince(ctx, db, 90*day),
		)
		if accumulatedErr != nil {
			logger.Warn("failed to refresh stats", "err", accumulatedErr)
		}
		select {
		case <-ctx.Done():
			return

		default:
			time.Sleep(refreshRate)
			continue
		}
	}
}

func fmtDuration(t time.Duration) string {
	if t == time.Duration(0) {
		return "ever"
	}
	return fmt.Sprintf("%dd", int(t.Hours()/24))
}

func refreshPageVisitsSince(ctx context.Context, db *sql.DB, since time.Duration) error {
	sinceString := fmtDuration(since)
	sinceAbsolute := time.Now().Add(-since)
	if since == time.Duration(0) {
		sinceAbsolute = time.UnixMilli(0)
	}
	errParams := map[string]string{"since": sinceString}
	query := `select count(*) from "s-rpc-portfolio-stats".visit where inserted_at > ($1)::timestamp`
	rows, err := db.QueryContext(ctx, query, sinceAbsolute)
	if err != nil {
		return terrors.Augment(err, "failed to query visits", errParams)
	}
	defer rows.Close()
	var counted int64
	for rows.Next() {
		err = rows.Scan(&counted)
		if err != nil {
			return terrors.Augment(err, "failed to scan visits query result", nil)
		}
	}
	visits.With(prometheus.Labels{"since": sinceString}).Set(float64(counted))
	return nil
}
