package locks

import (
	"context"
	"log/slog"
	"os"
	"sync"

	consul "github.com/hashicorp/consul/api"
	"github.com/monzo/terrors"
)

var clientMutex = &sync.Mutex{}
var consulClient *consul.Client

func getOrStart() (*consul.Client, error) {
	if consulClient != nil {
		return consulClient, nil
	}
	clientMutex.Lock()
	defer clientMutex.Unlock()

	if consulClient != nil {
		return consulClient, nil
	}
	consulAddr, ok := os.LookupEnv("DCOTTA_COM_NODE_CONSUL_ADDR")
	if !ok {
		return nil, terrors.PreconditionFailed("", "DCOTTA_COM_NODE_CONSUL_ADDR not found - seems we're not running in Nomad?", nil)
	}
	c, err := consul.NewClient(&consul.Config{
		Address: consulAddr,
	})
	if err != nil {
		return nil, terrors.Augment(err, "failed to init Consul client", nil)
	}
	consulClient = c
	return c, nil
}

var defaultQueryOpts = &consul.QueryOptions{}

type Lock struct {
	consulLock *consul.Lock
	Lost       <-chan struct{}
}

func Grab(key string) (*Lock, error) {
	errParams := map[string]string{"lockKey": key}
	client, err := getOrStart()
	if err != nil {
		return nil, terrors.Augment(err, "consul client not initialised", nil)
	}
	lock, err := client.LockKey(key)
	if err != nil {
		return nil, terrors.Augment(err, "failed to acquire lock", errParams)
	}
	ch, err := lock.Lock(nil)
	if err != nil {
		return nil, terrors.Augment(err, "failed to acquire lock", errParams)
	}

	return &Lock{
		consulLock: lock,
		Lost:       ch,
	}, nil
}
func (l *Lock) Release(ctx context.Context) {
	err := l.consulLock.Unlock()
	if err != nil {
		slog.WarnContext(ctx, "failed to release lock", "err", err.Error())
	}
}
