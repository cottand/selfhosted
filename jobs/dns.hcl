job "dns" {
  datacenters = ["dc1"]
  type        = "system"
  group "grimd-dns" {
    network {
      mode = "bridge"
      port "dns" {
        static       = 53
        host_network = "wg-mesh"
      }
      // port "dns-public" {
      //     static = 53
      // }
      port "metrics" {
        to           = 4000
        host_network = "wg-mesh"
      }
    }


    service {
      name     = "dns-metrics"
      provider = "nomad"
      port     = "metrics"
      tags     = ["metrics"]
    }
    service {
      name     = "dns"
      provider = "nomad"
      port     = "dns"
      check {
        name     = "alive"
        type     = "tcp"
        port     = "metrics"
        interval = "20s"
        timeout  = "2s"
      }
    }
    task "grimd-dns" {
      driver = "docker"
      config {
        image = "ghcr.io/cottand/grimd:sha-b32cc5f"
        args = [
          "--config", "/config.toml",
          "--update",
        ]
        volumes = [
          "local/config.toml:/config.toml",
        ]
        ports = ["dns", "metrics"]
      }
      env = {
        "environment" = "TZ=Europe/Berlin"
      }
      resources {
        cpu    = 80
        memory = 80
      }
      template {
        destination = "local/config.toml"
        # see https://github.com/miekg/dns/blob/master/doc.go#L23C24-L23C58
        data = <<EOF
version = "1.0.9"

# list of sources to pull blocklists from, stores them in ./sources
sources = [
    "https://mirror1.malwaredomains.com/files/justdomains",
    "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
    "https://sysctl.org/cameleon/hosts",
    "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt",
    "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt",
    "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-blocklist.txt"
]

# list of locations to recursively read blocklists from (warning, every file found is assumed to be a hosts-file or domain list)
sourcedirs = ["sources"]

# log configuration
# format: comma separated list of options, where options is one of 
#   file:<filename>@<loglevel>
#   stderr>@<loglevel>
#   syslog@<loglevel>
# loglevel: 0 = errors and important operations, 1 = dns queries, 2 = debug
# e.g. logconfig = "file:grimd.log@2,syslog@1,stderr@2"
# logconfig = "file:grimd.log@2,stderr@2"
logconfig = "stderr@1"

# apidebug enables the debug mode of the http api library
apidebug = false

# address to bind to for the DNS server
bind = "0.0.0.0:{{ env "NOMAD_PORT_dns"  }}"

# address to bind to for the API server
api = "0.0.0.0:{{ env "NOMAD_PORT_metrics"  }}"
# response to blocked queries with a NXDOMAIN
nxdomain = false
# ipv4 address to forward blocked queries to
nullroute = "0.0.0.0"
# ipv6 address to forward blocked queries to
nullroutev6 = "0:0:0:0:0:0:0:0"
# nameservers to forward queries to
nameservers = ["1.1.1.1:53", "1.0.0.1:53"]
# concurrency interval for lookups in miliseconds
interval = 200
# query timeout for dns lookups in seconds
timeout = 5
# cache entry lifespan in seconds
expire = 600
# cache capacity, 0 for infinite
maxcount = 0
# question cache capacity, 0 for infinite but not recommended (this is used for storing logs)
questioncachecap = 5000
# manual blocklist entries
blocklist = []
# Drbl related settings
usedrbl = 0
drblpeersfilename = "drblpeers.yaml"
drblblockweight = 128
drbltimeout = 30
drbldebug = 0
# manual whitelist entries
whitelist = [
	"getsentry.com",
	"www.getsentry.com"
]

# manual custom dns entries
customdnsrecords = [
    # CNAME is not flattened - see https://github.com/looterz/grimd/issues/113
    "web.vps.dcotta.eu.     3600      IN  A   10.10.4.1  ",

    "nomad.vps.dcotta.eu.   3600      IN  CNAME   miki.mesh.dcotta.eu  ",
    "nomad.traefik.         3600      IN  CNAME   miki.mesh.dcotta.eu  ",
    "traefik.vps.dcotta.eu. 3600      IN  CNAME   miki.mesh.dcotta.eu  ",

    "web.vps.               3600      IN  CNAME   miki.mesh.dcotta.eu.  ",
    "_http._tcp.seaweedfs-master.nomad IN SRV 0 0 80 seaweed-master.vps.dcotta.eu",

    {{ range $i, $s := nomadService "seaweedfs-webdav" }}
    "webdav.vps            3600  IN  A   {{ .Address }}",
    {{ end }}

    {{ range $i, $s := nomadService "seaweedfs-master-http" }}
    "seaweedfs-master.vps  3600 IN  A   {{ .Address }}",
    {{ end }}
    "seaweed-master.vps.dcotta.eu  3600 IN  A   10.10.0.1",

    {{ range $i, $s := nomadService "seaweedfs-filer-http" }}
    "seaweedfs-filer.vps   3600 IN A {{ .Address }}",
    "seaweed-filer.vps.dcotta.eu   3600 IN  A   10.10.0.1",
    {{ end }}


    {{ $rr_a := sprig_list -}}
    {{- $rr_srv := sprig_list -}}
    {{- $base_domain := ".nomad" -}} {{- /* Change this field for a diferent tld! */ -}}
    {{- $ttl := 3600 -}}             {{- /* Change this field for a diferent ttl! */ -}}

    {{- /* Iterate over all of the registered Nomad services */ -}}
    {{- range nomadServices -}}
        {{ $service := . }}

        {{- /* Iterate over all of the instances of a services */ -}}
        {{- range nomadService $service.Name -}}
            {{ $svc := . }}


            {{- /* Generate a uniq label for IP */ -}}
            {{- $node := $svc.Address | md5sum | sprig_trunc 8 }}

            {{- /* Record A & SRV RRs */ -}}
            {{- $rr_a = sprig_append $rr_a (sprig_list $svc.Name $svc.Address) -}}
            {{- $rr_a = sprig_append $rr_a (sprig_list $node $svc.Address) -}}
            {{- $rr_srv = sprig_append $rr_srv (sprig_list $svc.Name $svc.Port $node) -}}
        {{- end -}}
    {{- end -}}

    {{- /* Iterate over lists and print everything */ -}}

    {{- /* Only the latest record will get returned - see https://github.com/looterz/grimd/issues/114 */ -}}
    {{ range $rr_srv -}}
    "{{ printf "%-45s %s %s %d %d %6d %s" (sprig_nospace (sprig_cat (index . 0) $base_domain ".srv")) "IN" "SRV" 0 0 (index . 1) (sprig_nospace (sprig_cat (index . 2) $base_domain )) }}",
    {{ end -}}

    {{- range $rr_a | sprig_uniq -}}
    "{{ printf "%-45s %4d %s %4s %s" (sprig_nospace (sprig_cat (index . 0) $base_domain)) $ttl "IN" "A" (sprig_last . ) }}",

    {{- /* A records to proxy: */ -}}
    "{{ printf "%-45s %4d %s %4s %s" (sprig_nospace (sprig_cat (index . 0) ".traefik")) $ttl "IN" "A" "10.10.4.1" }}",
    {{ end }}


]

# When this string is queried, toggle grimd on and off
togglename = ""

# If not zero, the delay in seconds before grimd automaticall reactivates after
# having been turned off.
reactivationdelay = 300

#Dns over HTTPS provider to use.
DoH = "https://cloudflare-dns.com/dns-query"
EOF
      }
    }
  }
}