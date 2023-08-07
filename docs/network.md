# Architecture

## Networking

I use Wireguard for inter-service communication. Every node is part of a wireguard mesh as follows

| box | IP (mesh) | IP (wg0) | location | 
|---|----|----|----|
| cosmo | 10.10.0.1 | 10.8.0.1 | contabo |
| elvis | 10.10.1.1 | 10.8.0.101  | london home |
| maco | 10.10.2.1 | 10.8.0.5  | london home |
| ari | 10.10.3.1 | 10.8.0.8 | london home |
| bianco | 10.10.4.1 | 10.8.102 | madrid