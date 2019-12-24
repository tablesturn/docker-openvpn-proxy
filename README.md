# Docker container to use OpenVPN client as proxy

Lightweight image to turn an OpenVPN client into a local http proxy server, allowing you to tunnel only specific applications through the VPN tunnel (and also different computers on your local network).

It comes with an integrated kill-mechanism which means that the proxy server will be killed before the VPN connection closes (even if something goes wrong with the VPN connection).

## Getting started

To use this image, you need a VPN server (provider) and a system to run the image. Because it bases on Alpine Linux, it can be built and run on multiple architectures (like Raspberry Pi). Dockerhub images coming soon.

### Prerequisites

You need the docker software installed to use this image. Also, keep in mind that docker might alter your iptables/firewall settings. At least, to me this was a problem. See fixes/workarounds down below.

### Building

```console
git clone https://github.com/tablesturn/docker-openvpn-proxy.git
cd docker-openvpn-proxy
docker build . -t tablesturn/docker-openvpn-proxy
```

### Installing

```console
docker run \
  --name vpn-proxy \
  --cap-add=NET_ADMIN \
  --publish 8118:8118 \
  --network host \
  --volume /path/to/vpn/config:/vpn \
  --detach \
  tablesturn/docker-openvpn-proxy
```

### Configuration

Place the openvpn configuration file as `client.conf` and the credentials file in your selected `/path/to/vpn/config` directory. Compare your vpn file to the `example-client.conf`. Make sure that the `client.conf` links to the file with login data, if needed:

```console
auth-user-pass credentials.conf
```

### Testing

Make sure that there are both an openvpn and a privoxy process running inside the docker container:

```console
# Run from inside the container using:
# docker exec -it vpn-proxy sh
top
```

If `both` are present, the connection should be working. Check it inside the container:

```console
# Run from inside the container using:
# docker exec -it vpn-proxy sh

ping 8.8.8.8        # Should work even when the DNS server is misconfigured
ping google.com     # Sould only work when the DNS server is configured properly
apk add curl        # Alpine Linux does not contain curl, you need it to test
curl ifconfig.me    # Should output the vpn server's public IPv4 address.
curl icanhazip.com  # Same. If this shows a IPv6 address, you are only tunneling IPv4 (or none).
```

Check if the proxy is accessible from the host

```console
curl ifconfig.me
# Your actual public IP
http_proxy=http://localhost:8118 curl ifconfig.me
# Something completely different
```

You should be able to connect from any proxy client (like FoxyProxy for use in browsers). Check your connection in your browser:

* [ifconfig.me](https://ifconfig.me) - Should output the vpn servers public IPv4 address.
* [icanhazip.com](https://icanhazip.com) - Same. If this shows a IPv6 address, you are only tunneling IPv4 (or none).
* [ipv6-test.com](https://ipv6-test.com) - Should tell you that you DID NOT configure IPv6.
* [ip8.com/webrtc-test](https://ip8.com/webrtc-test) - Checks your browser for WebRTC leaks
* [speedtest.net](https://speedtest.net) - Finally, a performance test

Congratulations! You are now using your VPN as a http proxy.

## What to expect

This is just a small project and I can not guarantee that there are no security flaws or leaks in some cases. There is no encryption running on the local side (http proxy only).

However, it worked for me and according to multiple online tests, my connection was "protected". Just keep in mind things like DNS leaks and WebRTC leaks.

Also, most VPN servers do not implement IPv6 compatibility. Therefore, I did neither.

## Troubleshooting

### No tunneling is used from inside the container

Something with your `client.conf` file or vpn server is wrong. Try to make your own VPN connection from inside the container:

```console
# Run from inside the container using:
# docker exec -it vpn-proxy sh
/usr/sbin/openvpn --cd /vpn --config client.conf
```

### I can not connect to the privoxy server

Either the proxy server isn't running or the port is not exposed to the host. Try to connect from your host:

```console
# Run on the host machine
http_proxy=http://localhost:8118 curl ifconfig.me
```

Take a look at your hosts iptables settings:

```console
sudo iptables -L -v
sudo ip6tables -L -v
```

Maybe there is an issue with your IPv6 `ip6tables`, meaning that a proxy client (maybe even localhost?) wants to connect using the docker-hosts IPv6 address, which rejects the connection?

### Docker messes with my iptables (or firewall settings)

Yes, this seems to be a known behaviour. Even trying to disable it with *--iptables=false* in docker configuration files does not change anything. You may have to create and pre-fill custom chains like *DOCKER-USER* and *DOCKER-ISOLATION-STAGE-1*. Think twice about using this image with a complex iptables firewall.

## Acknowledgments

* [Patrick Brisbin](https://github.com/pbrisbin) - Initial work
