package module

import (
	"bufio"
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
	prompb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-prometheus"
	"github.com/stretchr/testify/assert"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/emptypb"
)

const (
	testWriteTimeout = 200 * time.Millisecond
	testTempPeriod   = 20 * time.Millisecond
)

type fakeMqtt struct {
	pb.UnimplementedMqttServer
	updates chan *pb.LightStatus
	lights  []*pb.Light

	ended chan struct{}
}

type fakePrometheus struct {
	prompb.UnimplementedPrometheusServer
	mutex   sync.Mutex
	results map[string]string
	calls   atomic.Int32
}

func (f *fakePrometheus) QueryInstant(_ context.Context, req *prompb.QueryInstantRequest) (*prompb.QueryInstantResponse, error) {
	f.calls.Add(1)
	f.mutex.Lock()
	defer f.mutex.Unlock()
	result, ok := f.results[req.PromQLQuery]
	if !ok {
		return nil, errors.New("no result")
	}
	return &prompb.QueryInstantResponse{Result: result}, nil
}

func (f *fakePrometheus) set(query, result string) {
	f.mutex.Lock()
	defer f.mutex.Unlock()
	f.results[query] = result
}

func (f *fakePrometheus) clear(query string) {
	f.mutex.Lock()
	defer f.mutex.Unlock()
	delete(f.results, query)
}

func (f *fakeMqtt) ListLights(context.Context, *emptypb.Empty) (*pb.ListLightsResponse, error) {
	return &pb.ListLightsResponse{Lights: f.lights}, nil
}

func (f *fakeMqtt) GetLight(_ context.Context, req *pb.GetLightRequest) (*pb.LightStatus, error) {
	return &pb.LightStatus{Id: req.Id}, nil
}

func (f *fakeMqtt) SetLight(_ context.Context, req *pb.SetLightRequest) (*pb.LightStatus, error) {
	if req.Id == "broken" {
		return nil, errors.New("unreachable")
	}
	return &pb.LightStatus{Id: req.Id, On: req.GetOn()}, nil
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
var testPrometheus = &fakePrometheus{results: map[string]string{}}

var sharedFakeMqtt = sync.OnceValues(func() (*fakeMqtt, error) {
	listener, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		return nil, err
	}
	fake := &fakeMqtt{
		updates: make(chan *pb.LightStatus),
		lights:  []*pb.Light{{Id: "plug103"}},
		ended:   make(chan struct{}, 1),
	}
	server := grpc.NewServer()
	pb.RegisterMqttServer(server, fake)
	prompb.RegisterPrometheusServer(server, testPrometheus)
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
	server := (&scaffold{tempPeriod: testTempPeriod}).newServer(context.Background(), "test")
	server.WriteTimeout = testWriteTimeout
	go func() { _ = server.Serve(listener) }()
	t.Cleanup(func() { _ = server.Close() })
	return "http://" + listener.Addr().String()
}

func nextEvent(t *testing.T, events *bufio.Scanner, kind string) string {
	type result struct {
		event string
		ok    bool
	}
	got := make(chan result, 1)
	go func() {
		var event strings.Builder
		for events.Scan() {
			line := events.Text()
			if line == "" {
				if strings.Contains(event.String(), "event: "+kind) {
					got <- result{event.String(), true}
					return
				}
				event.Reset()
				continue
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

	snapshot := nextEvent(t, events, "light")
	assert.Contains(t, snapshot, `id="light-plug103"`)
	assert.Contains(t, snapshot, ">off<")

	time.Sleep(2 * testWriteTimeout)

	fake.updates <- &pb.LightStatus{Id: "plug103", On: true}
	update := nextEvent(t, events, "light")
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

func postLight(t *testing.T, id string, rowOnly bool) (*http.Response, string) {
	t.Helper()
	startFakeMqtt(t)
	request := httptest.NewRequest(http.MethodPost, "/lights/"+id, strings.NewReader("on=true"))
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	if rowOnly {
		request.Header.Set("X-Row-Only", "true")
	}
	recorder := httptest.NewRecorder()
	(&scaffold{}).MakeHTTPHandler().ServeHTTP(recorder, request)
	response := recorder.Result()
	body, err := io.ReadAll(response.Body)
	failOnError(t, err)
	return response, string(body)
}

func TestSetLightReturnsRow(t *testing.T) {
	response, body := postLight(t, "plug103", true)

	assert.Equal(t, http.StatusOK, response.StatusCode)
	assert.Contains(t, body, `id="light-plug103"`)
	assert.NotContains(t, body, "<html")
}

func TestSetLightRedirectsPlainForms(t *testing.T) {
	response, _ := postLight(t, "plug103", false)

	assert.Equal(t, http.StatusSeeOther, response.StatusCode)
	assert.Equal(t, "/", response.Header.Get("Location"))
}

func TestSetLightFailure(t *testing.T) {
	response, _ := postLight(t, "broken", true)

	assert.Equal(t, http.StatusBadGateway, response.StatusCode)
}

func TestAquariumTemp(t *testing.T) {
	startFakeMqtt(t)

	testPrometheus.set(aquariumTempQuery, "24.36")
	s := &scaffold{tempPeriod: time.Hour}
	assert.Equal(t, "24.4°C", s.aquariumTemp(context.Background()))

	calls := testPrometheus.calls.Load()
	testPrometheus.set(aquariumTempQuery, "30")
	assert.Equal(t, "24.4°C", s.aquariumTemp(context.Background()))
	assert.Equal(t, calls, testPrometheus.calls.Load())

	testPrometheus.clear(aquariumTempQuery)
	s = &scaffold{tempPeriod: time.Hour}
	assert.Equal(t, tempUnknown, s.aquariumTemp(context.Background()))

	testPrometheus.set(aquariumTempQuery, "not a number")
	s = &scaffold{tempPeriod: time.Hour}
	assert.Equal(t, tempUnknown, s.aquariumTemp(context.Background()))
}

func TestRoomTempIsCachedSeparately(t *testing.T) {
	startFakeMqtt(t)
	testPrometheus.set(aquariumTempQuery, "24")
	testPrometheus.set(roomTempQuery, "19.25")
	s := &scaffold{tempPeriod: time.Hour}

	assert.Equal(t, "24.0°C", s.aquariumTemp(context.Background()))
	assert.Equal(t, "19.2°C", s.roomTemp(context.Background()))
}

func TestOnlyAquariumLightShowsTemp(t *testing.T) {
	startFakeMqtt(t)
	testPrometheus.set(aquariumTempQuery, "24")
	s := &scaffold{tempPeriod: time.Hour}

	tank, err := renderLightEvent(context.Background(), s.withTemp(context.Background(), light{ID: aquariumLight, Known: true}))
	failOnError(t, err)
	assert.Contains(t, string(tank), `id="aquarium-temp"`)
	assert.Contains(t, string(tank), "24.0°C")

	plug, err := renderLightEvent(context.Background(), s.withTemp(context.Background(), light{ID: "plug103", Known: true}))
	failOnError(t, err)
	assert.NotContains(t, string(plug), "aquarium-temp")
}

func TestTempEvents(t *testing.T) {
	startFakeMqtt(t)
	testPrometheus.set(aquariumTempQuery, "24")
	testPrometheus.set(roomTempQuery, "19")
	url := startServer(t)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, url+"/lights/events", nil)
	failOnError(t, err)
	response, err := http.DefaultClient.Do(request)
	failOnError(t, err)
	defer response.Body.Close()
	events := bufio.NewScanner(response.Body)

	waitForEvent(t, events, "room-temp", "19.0°C")

	testPrometheus.set(aquariumTempQuery, "25")
	waitForEvent(t, events, "aquarium-temp", "25.0°C")

	testPrometheus.clear(roomTempQuery)
	waitForEvent(t, events, "room-temp", tempUnknown)
}

func waitForEvent(t *testing.T, events *bufio.Scanner, kind, data string) {
	t.Helper()
	for range 10 {
		if strings.Contains(nextEvent(t, events, kind), "data: "+data+"\n") {
			return
		}
	}
	t.Fatalf("no %s event with %s", kind, data)
}
