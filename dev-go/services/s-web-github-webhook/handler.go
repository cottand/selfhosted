package module

import (
	"context"
	"encoding/json"
	"github.com/monzo/terrors"
	"io"
	"net/http"
	"time"
)

type PushEvent struct {
	Ref string `json:"ref"`
}

var lastApplied = time.Unix(0, 0)
var stagger = 20 * time.Second

func handlePush() http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		newCtx := context.WithoutCancel(request.Context())
		go deploy(newCtx, request.Clone(newCtx).Body)
		writer.WriteHeader(http.StatusNoContent)
	})
}

func deploy(ctx context.Context, body io.ReadCloser) {
	defer func() {
		_ = body.Close()
	}()

	ctx, span := tracer.Start(ctx, "deployOnPush")
	defer span.End()

	if lastApplied.Add(stagger).After(time.Now()) {
		return
	}
	defer func() {
		lastApplied = time.Now()
	}()

	pushEvent := PushEvent{}
	decoder := json.NewDecoder(body)
	err := terrors.Propagate(decoder.Decode(&pushEvent))
	if err != nil {
		span.RecordError(err)
		logger.Warn("could not handle push event", "errorMsg", err.Error())
	}
	// TODO actually deploy!

}
