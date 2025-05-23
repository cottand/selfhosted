// Code generated by protoc-gen-go-grpc. DO NOT EDIT.
// versions:
// - protoc-gen-go-grpc v1.3.0
// - protoc             v4.25.4
// source: s-rpc-nomad-api/def.proto

package s_rpc_nomad_api

import (
	context "context"
	grpc "google.golang.org/grpc"
	codes "google.golang.org/grpc/codes"
	status "google.golang.org/grpc/status"
	emptypb "google.golang.org/protobuf/types/known/emptypb"
)

// This is a compile-time assertion to ensure that this generated file
// is compatible with the grpc package it is being compiled against.
// Requires gRPC-Go v1.32.0 or later.
const _ = grpc.SupportPackageIsVersion7

const (
	NomadApi_Deploy_FullMethodName = "/s_rpc_nomad_api.NomadApi/Deploy"
)

// NomadApiClient is the client API for NomadApi service.
//
// For semantics around ctx use and closing/ending streaming RPCs, please refer to https://pkg.go.dev/google.golang.org/grpc/?tab=doc#ClientConn.NewStream.
type NomadApiClient interface {
	Deploy(ctx context.Context, in *Job, opts ...grpc.CallOption) (*emptypb.Empty, error)
}

type nomadApiClient struct {
	cc grpc.ClientConnInterface
}

func NewNomadApiClient(cc grpc.ClientConnInterface) NomadApiClient {
	return &nomadApiClient{cc}
}

func (c *nomadApiClient) Deploy(ctx context.Context, in *Job, opts ...grpc.CallOption) (*emptypb.Empty, error) {
	out := new(emptypb.Empty)
	err := c.cc.Invoke(ctx, NomadApi_Deploy_FullMethodName, in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// NomadApiServer is the server API for NomadApi service.
// All implementations must embed UnimplementedNomadApiServer
// for forward compatibility
type NomadApiServer interface {
	Deploy(context.Context, *Job) (*emptypb.Empty, error)
	mustEmbedUnimplementedNomadApiServer()
}

// UnimplementedNomadApiServer must be embedded to have forward compatible implementations.
type UnimplementedNomadApiServer struct {
}

func (UnimplementedNomadApiServer) Deploy(context.Context, *Job) (*emptypb.Empty, error) {
	return nil, status.Errorf(codes.Unimplemented, "method Deploy not implemented")
}
func (UnimplementedNomadApiServer) mustEmbedUnimplementedNomadApiServer() {}

// UnsafeNomadApiServer may be embedded to opt out of forward compatibility for this service.
// Use of this interface is not recommended, as added methods to NomadApiServer will
// result in compilation errors.
type UnsafeNomadApiServer interface {
	mustEmbedUnimplementedNomadApiServer()
}

func RegisterNomadApiServer(s grpc.ServiceRegistrar, srv NomadApiServer) {
	s.RegisterService(&NomadApi_ServiceDesc, srv)
}

func _NomadApi_Deploy_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(Job)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(NomadApiServer).Deploy(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: NomadApi_Deploy_FullMethodName,
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(NomadApiServer).Deploy(ctx, req.(*Job))
	}
	return interceptor(ctx, in, info, handler)
}

// NomadApi_ServiceDesc is the grpc.ServiceDesc for NomadApi service.
// It's only intended for direct use with grpc.RegisterService,
// and not to be introspected or modified (even as a copy)
var NomadApi_ServiceDesc = grpc.ServiceDesc{
	ServiceName: "s_rpc_nomad_api.NomadApi",
	HandlerType: (*NomadApiServer)(nil),
	Methods: []grpc.MethodDesc{
		{
			MethodName: "Deploy",
			Handler:    _NomadApi_Deploy_Handler,
		},
	},
	Streams:  []grpc.StreamDesc{},
	Metadata: "s-rpc-nomad-api/def.proto",
}
