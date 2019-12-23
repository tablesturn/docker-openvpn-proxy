Proxy through an OpenVPN client connection.
Does not work yet.

Forked from pbrisbin/docker-openvpn-proxy to be able to use openvpn config files from the host and have the proxy only running if an openvpn connection is active (killswitch).

I am not sure if I didn't understand what he wanted to do with the original --volume.

We'll see if this works.

## Usage

```console
docker run \
  --name vpn \
  --cap-add=NET_ADMIN \
  --publish 8118:8118 \
  -v /path/to/vpnconfigfolder:/vpn \
  --detach \
  tablesturn/docker-openvpn-proxy
```

**Note**: `VPN_CERTIFICATE` can be an absolute path or relative to
`/etc/openvpn`. If the cert you intend to use is not present on the basic Alpine
system, be sure to pass it in via `--volume`.

```console
% curl ifconfig.me
<your actual public IP>
% http_proxy=http://localhost:8118 curl ifconfig.me
<something completely different>
```
