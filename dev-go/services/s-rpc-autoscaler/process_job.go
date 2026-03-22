package module

import (
	"context"

	nomad "github.com/hashicorp/nomad/api"
	"github.com/monzo/terrors"
)

const (
	autoscalingValueDisabled = "disabled"
	autoscalingValueEnabled  = "enabled"
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
	ok, err := isEligibleForAutoscaling(def.Meta)
	if err != nil {
		return terrors.Augment(err, "failed to check autoscaling status", errParams)
	}
	if !ok {
		return nil
	}

	for _, group := range def.TaskGroups {
		for _, task := range group.Tasks {
			ok, err := isEligibleForAutoscaling(task.Meta)
			if err != nil {
				return terrors.Augment(err, "failed to check autoscaling status", errParams)
			}
			if !ok {
				continue
			}

		}
	}
	return nil
}
