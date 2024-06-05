# [Self-hosted fleet](https://nico.dcotta.eu/projects/selfhosted-homelab)

This is the config-as-code of my personal machine cluster, which I use to self-host some services, including [my personal website](https://nico.dcotta.eu/projects/selfhosted-homelab).

The fleet is made up of
- 3 small servers hosted Contabo, in Germany
- 2 old machines in London, UK (in my living room)
- 1 old laptop in Madrid, Spain (this one is in my parents' living room)
- Cloudlfare proxies my public HTTP traffic


The technologies I use include
- [Wireguard](https://www.wireguard.com/) for the connection between nodes, so _all_ cluster communication is private and secure
- [Nomad](https://www.nomadproject.io/) for orchestrating containers, netwkoring, and storage
- [Vault](https//https://www.vaultproject.io/) for automating and storing secrets, including mTLS between services and my own ACME authority
- [Consul](https://www.consul.io/) for service discovery and service-mesh orchestration
- [NixOS](https://nixos.org/) for managing the bare-metal (and [Colmena](https://github.com/zhaofengli/colmena) for deploying remotely)
- [SeaweedFS](https://github.com/seaweedfs/seaweedfs) as a distributed filesystem to manage highly available persistent storage
- [CockroachDB](https://github.com/cockroachdb/cockroach) for HA distributed SQL databases
- [Leng](https://github.com/cottand/leng) (which I maintain myself) for DNS service-discovery and adblocking

I always set up the HA versions of the above. This means Raft storage for Vault, erasure coding for SeaweedFS, etc.

Configuration management is done declaratively, with Terraform (for the stateful services) and Nix (for the OS and package management).

Some of the services I host include
- Lemmy (think Mastodon but for Reddit)
- Immich (think self-hosted Google Photos)
- My personal portfolio website, [nico.dcotta.eu](https://nico.dcotta.eu)
- Personal storage for backups etc
- and some more as ideas come along!

