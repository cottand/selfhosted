package module

import (
	"github.com/cottand/selfhosted/dev-go/lib/util"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var buttonEvent = promauto.NewCounterVec(prometheus.CounterOpts{
	Namespace: util.KebabToSnakeCase(Name),
	Name:      "button_event",
	Help:      "A button press",
}, []string{"button"})
