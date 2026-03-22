package module

import (
	"context"

	"github.com/cottand/selfhosted/dev-go/lib/util"
	nomad "github.com/hashicorp/nomad/api"
	"github.com/monzo/terrors"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

const (
	autoscalingValueDisabled = "disabled"
	autoscalingValueEnabled  = "enabled"

	targetCPUPercentage    = 0.6
	targetMemoryPercentage = 0.8
)

var (
	targetCPUMetric = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: util.KebabToSnakeCase(name),
		Name:      "task_target_cpu",
		Help:      "Target CPU for task",
	}, []string{"nomad_job", "task_name", "task_group"})

	targetMemoryMetric = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: util.KebabToSnakeCase(name),
		Name:      "task_target_memorymb",
		Help:      "Target memory for task",
	}, []string{"nomad_job", "task_name", "task_group"})
)

func isEligibleForAutoscaling(meta map[string]string) (bool, error) {
	value, ok := meta["DCOTTA_COM_VERTICAL_AUTOSCALING"]
	if !ok || value == autoscalingValueDisabled {
		return false, nil
	}
	if value == autoscalingValueEnabled {
		return true, nil
	}

	return false, terrors.PreconditionFailed("bad_param", "DCOTTA_COM_AUTOSCALING must be either 'enabled' or 'disabled'", nil)
}

func processJob(ctx context.Context, def *nomad.Job) error {
	errParams := map[string]string{"jobId": *def.ID}
	for _, group := range def.TaskGroups {
		for _, task := range group.Tasks {
			ok, err := isEligibleForAutoscaling(task.Meta)
			if err != nil {
				return terrors.Augment(err, "failed to check autoscaling status", errParams)
			}
			if !ok {
				continue
			}

			targetCPU := targetCPUPercentage * float64(*task.Resources.CPU)
			targetMemory := targetMemoryPercentage * float64(*task.Resources.MemoryMB)

			targetCPUMetric.With(prometheus.Labels{
				"nomad_job":  *def.ID,
				"task_name":  task.Name,
				"task_group": *group.Name,
			}).Set(targetCPU)

			targetMemoryMetric.With(prometheus.Labels{
				"nomad_job":  *def.ID,
				"task_name":  task.Name,
				"task_group": *group.Name,
			}).Set(targetMemory)

		}
	}
	return nil
}
