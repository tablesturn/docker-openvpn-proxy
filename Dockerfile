FROM alpine:latest
MAINTAINER Tablesturn
RUN apk --update add openvpn privoxy supervisor
EXPOSE 8118
ADD files /
ENTRYPOINT ["/bin/entrypoint"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf", "-n"]
# Map config to host folder
VOLUME ["/vpn"]
