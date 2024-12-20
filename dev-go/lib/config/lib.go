package config

import (
	"context"
	consul "github.com/hashicorp/consul/api"
	"github.com/monzo/terrors"
	"log/slog"
	"os"
	"strconv"
)

type Value struct {
	key string
	ctx context.Context
}

func Init() error {
	localAddr, ok := os.LookupEnv("NONAD_HEALTH")
	if !ok {
		return terrors.PreconditionFailed("", "seems we're not running in Nomad?", nil)
	}
	c, err := consul.NewClient(&consul.Config{
		Address: "https://" + localAddr + ":8051",
	})
	if err != nil {
		return terrors.Augment(err, "failed to init Consul client", nil)
	}
	client = c
	return nil
}

var client *consul.Client

var defaultQueryOpts = &consul.QueryOptions{}

func Get(ctx context.Context, key string) *Value {
	return &Value{key: key, ctx: ctx}
}

func (v *Value) getKV() (*consul.KVPair, error) {
	if client == nil {
		return nil, terrors.InternalService("init_failed", "consul client not initialised", nil)
	}

	kv, _, err := client.KV().Get(v.key, defaultQueryOpts.WithContext(v.ctx))
	if err != nil {
		return nil, terrors.Augment(err, "failed to query Consul KV", nil)
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

// Bool has default which is always false
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
