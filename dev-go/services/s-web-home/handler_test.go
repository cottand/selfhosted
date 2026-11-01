package module

import (
	"bufio"
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
	"github.com/stretchr/testify/assert"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/emptypb"
)

const testWriteTimeout = 200 * time.Millisecond

type fakeMqtt struct {
	pb.UnimplementedMqttServer
	updates chan *pb.LightStatus

	ended chan struct{}
}

func (f *fakeMqtt) ListLights(context.Context, *emptypb.Empty) (*pb.ListLightsResponse, error) {
	return &pb.ListLightsResponse{Lights: []*pb.Light{{Id: "plug103"}}}, nil
}

func (f *fakeMqtt) GetLight(_ context.Context, req *pb.GetLightRequest) (*pb.LightStatus, error) {
	return &pb.LightStatus{Id: req.Id}, nil
}

func (f *fakeMqtt) WatchLights(_ *emptypb.Empty, stream grpc.ServerStreamingServer[pb.LightStatus]) error {
	defer func() { f.ended <- struct{}{} }()
	if err := stream.SendHeader(nil); err != nil {
		return err
	}
	for {
		select {
		case <-stream.Context().Done():
			return nil
		case status := <-f.updates:
			if err := stream.Send(status); err != nil {
				return err
			}
		}
	}
}

func failOnError(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

// the generated client keeps its first connection, so all tests share one server
var sharedFakeMqtt = sync.OnceValues(func() (*fakeMqtt, error) {
	listener, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		return nil, err
	}
	fake := &fakeMqtt{updates: make(chan *pb.LightStatus), ended: make(chan struct{}, 1)}
	server := grpc.NewServer()
	pb.RegisterMqttServer(server, fake)
	go func() { _ = server.Serve(listener) }()

	_, port, err := net.SplitHostPort(listener.Addr().String())
	if err != nil {
		return nil, err
	}
	return fake, os.Setenv("GRPC_PORT", port)
})

func startFakeMqtt(t *testing.T) *fakeMqtt {
	fake, err := sharedFakeMqtt()
	failOnError(t, err)
	return fake
}

func startServer(t *testing.T) string {
	listener, err := net.Listen("tcp", "localhost:0")
	failOnError(t, err)
	server := (&scaffold{}).newServer(context.Background(), "test")
	server.WriteTimeout = testWriteTimeout
	go func() { _ = server.Serve(listener) }()
	t.Cleanup(func() { _ = server.Close() })
	return "http://" + listener.Addr().String()
}

func nextEvent(t *testing.T, events *bufio.Scanner) string {
	type result struct {
		event string
		ok    bool
	}
	got := make(chan result, 1)
	go func() {
		var event strings.Builder
		for events.Scan() {
			line := events.Text()
			if line == "" && strings.Contains(event.String(), "event: light") {
				got <- result{event.String(), true}
				return
			}
			event.WriteString(line + "\n")
		}
		got <- result{event.String(), false}
	}()
	select {
	case r := <-got:
		if !r.ok {
			t.Fatalf("stream ended: %s", r.event)
		}
		return r.event
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for an event")
		return ""
	}
}

func TestLightEvents(t *testing.T) {
	fake := startFakeMqtt(t)
	url := startServer(t)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, url+"/lights/events", nil)
	failOnError(t, err)
	response, err := http.DefaultClient.Do(request)
	failOnError(t, err)
	defer response.Body.Close()
	assert.Equal(t, "text/event-stream", response.Header.Get("Content-Type"))
	events := bufio.NewScanner(response.Body)

	snapshot := nextEvent(t, events)
	assert.Contains(t, snapshot, `id="light-plug103"`)
	assert.Contains(t, snapshot, ">off<")

	time.Sleep(2 * testWriteTimeout)

	fake.updates <- &pb.LightStatus{Id: "plug103", On: true}
	update := nextEvent(t, events)
	assert.Contains(t, update, `id="light-plug103"`)
	assert.Contains(t, update, ">on<")

	cancel()
	select {
	case <-fake.ended:
	case <-time.After(5 * time.Second):
		assert.Fail(t, "watch was not cancelled when the client went away")
	}
}

func TestRenderLightEvent(t *testing.T) {
	event, err := renderLightEvent(context.Background(), light{ID: "rgb105", Dimmable: true, Known: true, On: true, Brightness: 40})
	failOnError(t, err)

	lines := strings.Split(strings.TrimSuffix(string(event), "\n\n"), "\n")
	assert.Equal(t, "event: light", lines[0])
	for _, line := range lines[1:] {
		assert.True(t, strings.HasPrefix(line, "data: "), line)
	}
}

func TestFloorplan(t *testing.T) {
	recorder := httptest.NewRecorder()
	(&scaffold{}).MakeHTTPHandler().ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/floorplan.svg", nil))

	assert.Equal(t, http.StatusOK, recorder.Code)
	assert.Equal(t, "image/svg+xml", recorder.Header().Get("Content-Type"))
	assert.Contains(t, recorder.Body.String(), "<svg")
}
