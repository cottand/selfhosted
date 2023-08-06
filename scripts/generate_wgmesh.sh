#!/usr/bin/env bash

set -e

# see https://github.com/k4yt3x/wg-meshconf for installation

DNS="--dns 10.8.0.1"
PORT="--listenport 55820"

wg-meshconf addpeer cosmo --address 10.10.0.1/24 --endpoint cosmo.vps.dcotta.eu $DNS $PORT
wg-meshconf addpeer elvis --address 10.10.1.1/24 --endpoint elvis.vps6.dcotta.eu $DNS $PORT
wg-meshconf addpeer maco --address 10.10.2.1/24 --endpoint maco.vps6.dcotta.eu $DNS $PORT
wg-meshconf addpeer ari --address 10.10.3.1/24 --endpoint ari.vps6.dcotta.eu $DNS $PORT
# wg-meshconf addpeer bianco --address 10.10.4.1/24 --endpoint bianco.vps.dcotta.eu


wg-meshconf genconfig -o secret/wg-mesh