package module

import (
	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	nomad "github.com/hashicorp/nomad/api"
)

type ProtoHandler struct {
	pb.UnimplementedNomadApiServer
	nomadClient *nomad.Client
}
