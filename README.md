Proxy through an OpenVPN client connection.

This is quite unstable and I am still having IPv6 issues: IPv6 traffic is not tunneled trough vpn

Forked from pbrisbin/docker-openvpn-proxy

Changes done to his version:

Now it is possible to use config files from the host file system.

The proxy only running if an openvpn connection is active (killswitch).

I am still not sure if I didn't understand what he wanted to do with the original --volume. However, the killswitch seems to be important in most situations.

For me (raspberry pi running debian), Docker somewhat constantly broke my iptables and I was not able to bypass this using --iptables=false. The hotfix was a script I had to run manually after rebooting to load my firewall settings.

## Usage

```console
docker run \
  --name vpn-proxy \
  --cap-add=NET_ADMIN \
  --publish 8118:8118 \
  --network host \
  --volume ~/cyber:/vpn \
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
