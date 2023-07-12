# Self-hosted fleet

This is the config-as-code of my personal machine cluster, which I use to self-host some services (including [a blog post](https://nico.dcotta.eu/blog/nomad) about this!).

The fleet is made up of
- 1 small server hosted Contabo, in Germany
- 3 old machines in London, UK (2 in my living room, 1 in my bedroom)
- 1 old laptop in Madrid, Spain (this one is in my mother's living room)
- Cloudlfare proxies my public HTTP traffic


The technologies I use include
- [Wireguard](https://www.wireguard.com/) for the connection between nodes, so _all_ cluster communication everything is private and secure
- [Nomad](https://www.nomadproject.io/) for orchestrating containers
- [NixOS](https://nixos.org/) for managing the bare-metal (and [Colmena](https://github.com/zhaofengli/colmena) for deploying the remote config to each node)
- [SeaweedFS](https://github.com/seaweedfs/seaweedfs) as a distributed filesystem to manage highly available persistent storage

Some of the services I host include
- Lemmy (think Mastodon but for Reddit)
- My personal portfolio website, [nico.dcotta.eu](https://nico.dcotta.eu)
- Private DNS with adblocking
- Personal storage for backups etc
- and some more as ideas come along!

