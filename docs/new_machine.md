# Adding a new machine to the fleet

1. Set up NixOS
2. Make sure you can SSH from admin client to root non-interactively
3. Set up DNS
    - if possible, machine should be reachable by `<name>.vps6.dcotta.eu` on (ideally) IPv6
    - if the box is inside a router's NAT, open up the firewall of the router to allow connections to it (done on london)
    - if the box is on cloud, allow the router firewall to reach london's IPv6 subnet (`/64`)
    - test with a ping
4. Set up WG mesh
    - create private/public keypair and add peer config to all other machines. The new peer should look like the following:
    ```conf
    # on the new machine:
        [Interface]
        # Name: <new-name>
        Address = 10.10.X.1/32
        PrivateKey = <private-key>
        ListenPort = 55820
        DNS = 1.1.1.1

        # and onfig of other machines as peers follows (just copy paste from another peer and add itself)

    # on all of the existing machines:
    [Peer]
    # Name: <new-name>
    PublicKey = 3hukJD7Q1AwnjojHScJwGKhmPkZNDSYLGWh66AJSuxg=
    Endpoint = <new-name>.vps6.dcotta.eu:55820
    AllowedIPs = 10.10.X.1/24
    PersistentKeepalive = 15
    ```
    - `colmena apply` on those other machines
    - import `wg-mesh` config on new-machine definition
    - `colmena apply` on new-machine
    - sanity check `ping` works!
    - might want to add this peer to the admin mesh WG config on the client as well
