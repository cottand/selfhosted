// Code generated by protoc-gen-go-grpc. DO NOT EDIT.
// versions:
// - protoc-gen-go-grpc v1.3.0
// - protoc             v4.25.4
// source: s-rpc-vault/def.proto

package s_rpc_vault

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
	VaultApi_Snapshot_FullMethodName = "/s_rpc_vault.VaultApi/Snapshot"
)

// VaultApiClient is the client API for VaultApi service.
//
// For semantics around ctx use and closing/ending streaming RPCs, please refer to https://pkg.go.dev/google.golang.org/grpc/?tab=doc#ClientConn.NewStream.
type VaultApiClient interface {
	Snapshot(ctx context.Context, in *emptypb.Empty, opts ...grpc.CallOption) (*emptypb.Empty, error)
}

type vaultApiClient struct {
	cc grpc.ClientConnInterface
}

func NewVaultApiClient(cc grpc.ClientConnInterface) VaultApiClient {
	return &vaultApiClient{cc}
}

func (c *vaultApiClient) Snapshot(ctx context.Context, in *emptypb.Empty, opts ...grpc.CallOption) (*emptypb.Empty, error) {
	out := new(emptypb.Empty)
	err := c.cc.Invoke(ctx, VaultApi_Snapshot_FullMethodName, in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// VaultApiServer is the server API for VaultApi service.
// All implementations must embed UnimplementedVaultApiServer
// for forward compatibility
type VaultApiServer interface {
	Snapshot(context.Context, *emptypb.Empty) (*emptypb.Empty, error)
	mustEmbedUnimplementedVaultApiServer()
}

// UnimplementedVaultApiServer must be embedded to have forward compatible implementations.
type UnimplementedVaultApiServer struct {
}

func (UnimplementedVaultApiServer) Snapshot(context.Context, *emptypb.Empty) (*emptypb.Empty, error) {
	return nil, status.Errorf(codes.Unimplemented, "method Snapshot not implemented")
}
func (UnimplementedVaultApiServer) mustEmbedUnimplementedVaultApiServer() {}

// UnsafeVaultApiServer may be embedded to opt out of forward compatibility for this service.
// Use of this interface is not recommended, as added methods to VaultApiServer will
// result in compilation errors.
type UnsafeVaultApiServer interface {
	mustEmbedUnimplementedVaultApiServer()
}

func RegisterVaultApiServer(s grpc.ServiceRegistrar, srv VaultApiServer) {
	s.RegisterService(&VaultApi_ServiceDesc, srv)
}

func _VaultApi_Snapshot_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(emptypb.Empty)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(VaultApiServer).Snapshot(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: VaultApi_Snapshot_FullMethodName,
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(VaultApiServer).Snapshot(ctx, req.(*emptypb.Empty))
	}
	return interceptor(ctx, in, info, handler)
}

// VaultApi_ServiceDesc is the grpc.ServiceDesc for VaultApi service.
// It's only intended for direct use with grpc.RegisterService,
// and not to be introspected or modified (even as a copy)
var VaultApi_ServiceDesc = grpc.ServiceDesc{
	ServiceName: "s_rpc_vault.VaultApi",
	HandlerType: (*VaultApiServer)(nil),
	Methods: []grpc.MethodDesc{
		{
			MethodName: "Snapshot",
			Handler:    _VaultApi_Snapshot_Handler,
		},
	},
	Streams:  []grpc.StreamDesc{},
	Metadata: "s-rpc-vault/def.proto",
}