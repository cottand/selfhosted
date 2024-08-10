package bedrock

import "net/http"

import (
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func Init() {
	http.Handle("/metrics", promhttp.Handler())
	http.ListenAndServe(":2112", nil)
}
