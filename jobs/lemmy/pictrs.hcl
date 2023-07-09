
job "lemmy-pictures" {
  datacenters = ["dc1"]
  type        = "service"


  group "pictrs" {
    // volume "pictrs" {
    //   type            = "csi"
    //   read_only       = false
    //   source          = "lemmy-pictrs"
    //   access_mode     = "single-node-writer"
    //   attachment_mode = "file-system"
    // }
    network {
      mode = "bridge"
      port "http" {
        host_network = "vpn"
        to           = 8080
      }
    }
    task "pictrs" {
      service {
        name = "lemmy-pictrs"
        port = "http"
        provider = "nomad"
        check {
          name     = "alive"
          type     = "tcp"
          port     = "http"
          interval = "20s"
          timeout  = "2s"
        }
      }
      // volume_mount {
      //   volume      = "pictrs"
      //   destination = "/var/lib/pictrs"
      //   read_only   = false
      // }
        driver = "docker"
      config {
        image = "asonix/pictrs:0.4.0-rc.14"
        ports = ["http"]
        entrypoint = [
          "pict-rs",
          "-c", "/etc/pict-rs.d/config.toml",
          "run",
          // "object-storage",
        ]
    mount {
      type   = "bind"
      source = "local/pict-rs.toml"
      target = "/etc/pict-rs.d/config.toml"
    }
      }
    

      template {
        destination = "local/pict-rs.toml"
        change_mode = "restart"
        data = <<EOF
[server]
address = '0.0.0.0:8080'

# Not specifying api_key disables internal endpoints
api_key = 'API_KEY'

## Optional: connection pool size for internal http client
# This number can be lowered to keep pict-rs within ulimit bounds if you encounter errors related to
client_pool_size = 100
[tracing.logging]
# available options: compact, json, normal, pretty
format = 'normal'

# Dictates which traces should print to stdout
# default: warn,tracing_actix_web=info,actix_server=info,actix_web=info
targets = 'warn,tracing_actix_web=info,actix_server=info,actix_web=info'

# This is the number of _events_ to buffer, not the number of bytes. In reality, the amount of
# RAM used will be significatnly larger (in bytes) than the buffer capacity (in events)
# default: 102400
buffer_capacity = 102400

[tracing.opentelemetry]
## Optional: url for exporting otlp traces
# default: empty
# Not specifying opentelemetry_url means no traces will be exported
# When set, pict-rs will export OpenTelemetry traces to the provided URL. If the URL is
# inaccessible, this can cause performance degredation in pict-rs, so it is best left unset unless
# you have an OpenTelemetry collector
#url = 'http://localhost:4317/'
#service_name = 'pict-rs'

## Optional: trace level to export
# default: info
targets = 'info'

[media]
## Optional: preprocessing steps for uploaded images
# This configuration is the same format as the process endpoint's query arguments
# default: empty
# preprocess_steps = 'crop=16x9&resize=1200&blur=0.2'

## Optional: max media width (in pixels)
# default: 10,000
max_width = 10000

## Optional: max media height (in pixels)
# default: 10,000
max_height = 10000

## Optional: max media area (in pixels)
# default: 40,000,000
max_area = 40000000

## Optional: max file size (in Megabytes)
# default: 40
max_file_size = 40

## Optional: max frame count
# default: # 900
max_frame_count = 900

## Optional: enable GIF, MP4, and WEBM uploads (without sound)
enable_silent_video = true
## Optional: enable MP4, and WEBM uploads (with sound) and GIF (without sound)
enable_full_video = false

# available options: av1, h264, h265, vp8, vp9
video_codec = "vp9"

# default: empty
#
# available options: aac, opus, vorbis
# The audio codec is automatically selected based on video codec, but can be overriden
# av1, vp8, and vp9 map to opus
# h264 and h265 map to aac
# vorbis is not default for any codec
audio_codec = "aac"

# default: ['blur', 'crop', 'identity', 'resize', 'thumbnail']
filters = ['blur', 'crop', 'identity', 'resize', 'thumbnail']

## Optional: set file type for all uploads
# environment variable: PICTRS__MEDIA__FORMAT
# default: empty
# available options: avif, png, jpeg, jxl, webp
# When set, all uploaded still images will be converted to this file type. For balancing quality vs
# file size vs browser support, 'avif', 'jxl', and 'webp' should be considered. By default, images
# are stored in their original file type.
format = "webp"

[media.gif]
# If a gif does not fit within this bound, it will either be transcoded to a video or rejected,
# depending on whether video uploads are enabled
max_width = 128

# If a gif does not fit within this bound, it will either be transcoded to a video or rejected,
# depending on whether video uploads are enabled
max_height = 128

# If a gif does not fit within this bound, it will either be transcoded to a video or rejected,
# depending on whether video uploads are enabled
max_area = 16384

# If a gif does not fit within this bound, it will either be transcoded to a video or rejected,
# depending on whether video uploads are enabled
max_frame_count = 100


# [repo]
## Optional: database backend to use
# environment variable: PICTRS__REPO__TYPE
# default: sled
#
# available options: sled
# type = 'sled'

## Optional: path to sled repository
# environment variable: PICTRS__REPO__PATH
# default: /mnt/sled-repo
# path = '/mnt/sled-repo'

## Optional: in-memory cache capacity for sled data (in bytes)
# environment variable: PICTRS__REPO__CACHE_CAPACITY
# default: 67,108,864 (1024 * 1024 * 64, or 64MB)
# cache_capacity = 67108864


[store]
# default: filesystem
# available options: filesystem, object_storage
type = 'object_storage'

# When this is true, objects will be fetched from http{s}://{endpoint}:{port}/{bucket_name}/{object}
# When false, objects will be fetched from http{s}://{bucket_name}.{endpoint}:{port}/{object}
# Set to true when using minio
use_path_style = true

bucket_name = 'dcotta-lemmy-pictrs'
{{ with nomadVar "secret/buckets/dcotta-lemmy-pictrs" }}
access_key = "{{ .keyId }}"
secret_key = "{{ .secretAccessKey }}"     # if empty, loads from the shared credentials file (~/.aws/credentials).
# bucket = "{{ .bucketName }}"
# examples:
# - `http://localhost:9000` # minio
# - `https://s3.dualstack.eu-west-1.amazonaws.com` # s3
endpoint = "https://{{ .endpoint }}"
{{ end }}
region = "us-east-005"

# default: empty
# session_token = 'SESSION_TOKEN'
        EOF
      }
    }
  }
}