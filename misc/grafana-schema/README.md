# Grafana + postgresql

This is a script that will run Grafana for the first time against a fresh postgres DB

The idea is to let Grafana run its migrations on it, then import that into CockroachDB (basically, HA postgres).
The need for this arises from the fact that Grafana migrations don't work well on CockraochDB directly.

```bash
docker-compose up

img=$(podman ps -a --format '[ "{{.ID}}" , "{{ .Names }}" ]' | grep pg | jq -r '.[0]')

podman exec -it $img pg_dump grafana -U grafana > grafana.sql

docker-compose down
```