#!/bin/sh

# see https://github.com/hashicorp/nomad/issues/16762

set -e

services=$(nomad service list -t '{{ range (index . 0).Services }}{{printf "%s\n" .ServiceName }}{{ end }}')

for svc in $services; do
	echo "checking $svc:"
	data=$(nomad service info -t '{{ range . }}{{ printf "%s" .AllocID }}%{{ printf "%s\n" .ID }}{{ end }}' "$svc" | uniq)

	for d in $data; do
		alloc=$(echo "$d" | cut -d'%' -f1)
		svc_id=$(echo "$d" | cut -d'%' -f2)
		echo "    checking $alloc ($svc_id)"
		if ! nomad alloc status "$alloc" > /dev/null 2>&1; then
			echo "    !! removing $svc_id"
			nomad service delete "$svc" "$svc_id" > /dev/null 2>&1
		fi
	done
	echo
done
