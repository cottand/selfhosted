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
	"go.opentelemetry.io/otel/codes"
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

	visitsUniqueWithUri = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: bedrock.KebabToSnakeCase(Name),
		Name:      "page_visits_unique_url",
		Help:      "Unique page visits to web_portfolio per URL",
	}, []string{"since", "url"})
)

// RefreshPromStats returns when ctx is cancelled or done
func RefreshPromStats(ctx context.Context, db *sql.DB) {
	day := 24 * time.Hour
	durations := []time.Duration{0, day, 7 * day, 30 * day, 90 * day}
	for {
		ctx, span := tracer.Start(ctx, "periodic.refreshPromStats")
		var errs []error
		for _, duration := range durations {
			err1 := refreshPageVisitsSince(ctx, db, duration)
			err2 := refreshUniquePageVisitsSince(ctx, db, duration)
			err3 := refreshUniquePageVisitsSinceWithURL(ctx, db, duration)
			errs = append(errs, err1, err2, err3)
		}
		accumulated := errors.Join(errs...)
		if accumulated != nil {
			span.RecordError(accumulated)
			span.SetStatus(codes.Error, "error")
			slog.WarnContext(ctx, "failed to refresh stats", "err", accumulated)
		}
		span.SetStatus(codes.Ok, "ok")
		span.End()
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

func refreshUniquePageVisitsSince(ctx context.Context, db *sql.DB, since time.Duration) error {
	sinceString := fmtDuration(since)
	sinceAbsolute := time.Now().Add(-since)
	if since == time.Duration(0) {
		sinceAbsolute = time.UnixMilli(0)
	}
	errParams := map[string]string{"since": sinceString}
	query := `select count(distinct fingerprint_v1) from "s-rpc-portfolio-stats".visit where inserted_at > ($1)::timestamp`
	rows, err := db.QueryContext(ctx, query, sinceAbsolute)
	if err != nil {
		return terrors.Augment(err, "failed to query unique visits", errParams)
	}
	defer rows.Close()
	var counted int64
	for rows.Next() {
		err = rows.Scan(&counted)
		if err != nil {
			return terrors.Augment(err, "failed to scan unique visits query result", nil)
		}
	}
	visitsUnique.With(prometheus.Labels{"since": sinceString}).Set(float64(counted))
	return nil
}

func refreshUniquePageVisitsSinceWithURL(ctx context.Context, db *sql.DB, since time.Duration) error {
	sinceString := fmtDuration(since)
	sinceAbsolute := time.Now().Add(-since)
	if since == time.Duration(0) {
		sinceAbsolute = time.UnixMilli(0)
	}
	errParams := map[string]string{"since": sinceString}
	query := `
      select count(distinct fingerprint_v1), visit.url 
		from "s-rpc-portfolio-stats".visit
		where inserted_at > ($1)::timestamp
		group by visit.url
	`
	rows, err := db.QueryContext(ctx, query, sinceAbsolute)
	if err != nil {
		return terrors.Augment(err, "failed to query unique visits", errParams)
	}
	defer rows.Close()
	for rows.Next() {
		var count int64
		var url string
		err = rows.Scan(&count, &url)
		if err != nil {
			return terrors.Augment(err, "failed to scan unique visits query result", nil)
		}
		visitsUniqueWithUri.
			With(prometheus.Labels{"since": sinceString, "url": url}).
			Set(float64(count))
	}
	return nil
}
