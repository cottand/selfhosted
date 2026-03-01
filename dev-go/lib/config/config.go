package config

import (
	"context"
	"fmt"
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	consul "github.com/hashicorp/consul/api"
	"github.com/monzo/terrors"
	"log/slog"
	"os"
	"strconv"
	"sync"
)

const (
	ConsulKeyPrefix = "services/"
)

type Value struct {
	key string
	ctx context.Context
}

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

func Get(ctx context.Context, key string) *Value {
	return &Value{key: key, ctx: ctx}
}

func (v *Value) consulKVPath() string {
	moduleName, ok := bedrock.GetModuleName(v.ctx)
	if !ok {
		slog.WarnContext(v.ctx, "failed to get module name from context", "resolvedPath", fmt.Sprintf("%s/%s/%s", ConsulKeyPrefix, moduleName, v.key))
	}
	return fmt.Sprintf("%s/%s/%s", ConsulKeyPrefix, moduleName, v.key)
}

func (v *Value) getKV() (*consul.KVPair, error) {
	client, err := getOrStart()
	if err != nil {
		return nil, terrors.Augment(err, "consul client not initialised", nil)
	}

	path := v.consulKVPath()
	slog.DebugContext(v.ctx, "reading Consul secret", "path", path)
	kv, _, err := client.KV().Get(path, defaultQueryOpts.WithContext(v.ctx))
	if err != nil {
		return nil, terrors.Augment(err, "failed to query Consul KV", nil)
	}
	if kv == nil {
		return nil, terrors.NotFound("", "key not found", map[string]string{"path": path, "key": v.key})
	}
	return kv, nil
}

func (v *Value) String(default_ string) (string, error) {
	kv, err := v.getKV()
	if err != nil {
		return default_, err
	}
	return string(kv.Value), nil
}

// Bool returns false by default
func (v *Value) Bool() (bool, error) {
	kv, err := v.getKV()
	if err != nil {
		return false, err
	}
	b, err := strconv.ParseBool(string(kv.Value))
	if err != nil {
		slog.WarnContext(v.ctx, "failed to parse bool from config", "err", err)
	}
	return b, err
}
