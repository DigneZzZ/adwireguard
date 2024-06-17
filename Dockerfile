# Stage 1 - Build wg-easy
FROM node:18-alpine as wg-easy-build
WORKDIR /app
COPY wg-easy /app
RUN npm install -g npm@latest
RUN npm install     # This generates package-lock.json
RUN npm ci --omit=dev

# Stage 2 - Install AdGuardHome
FROM alpine:3.18 as adguardhome-build
RUN apk --no-cache add curl
COPY adgh /adgh
WORKDIR /adgh
RUN apk add --no-cache tar && \
    curl -sSfL -o AdGuardHome_linux_amd64.tar.gz $(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | \
    grep 'browser_download_url.*linux_amd64.tar.gz' | \
    cut -d '"' -f 4) && \
    tar -xzvf AdGuardHome_linux_amd64.tar.gz && \
    mv AdGuardHome /opt/adguardhome && \
    rm AdGuardHome_linux_amd64.tar.gz

# Final Stage - Combine Both
FROM alpine:3.18
RUN apk --no-cache add ca-certificates libcap tzdata dpkg dumb-init iptables wireguard-tools nodejs npm
COPY --from=wg-easy-build /app /app
COPY --from=adguardhome-build /opt/adguardhome /opt/adguardhome
RUN setcap 'cap_net_bind_service=+eip' /opt/adguardhome/AdGuardHome
WORKDIR /app    # Adjusted to /app where wg-easy files are copied

# Environment Variables
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV DEBUG=Server,WireGuard

# Entrypoint and Cmd
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["sh", "-c", "/opt/adguardhome/AdGuardHome -h 0.0.0.0 -p 53 & cd /app && npm start"]

# Expose necessary ports
EXPOSE 53/udp
EXPOSE 53/tcp
EXPOSE 3000/tcp
