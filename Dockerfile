# Начнем с базового образа Alpine
FROM alpine:3.18

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF

LABEL maintainer="AdGuard Team <devteam@adguard.com>" \
    org.opencontainers.image.authors="AdGuard Team <devteam@adguard.com>" \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.description="Network-wide ads & trackers blocking DNS server" \
    org.opencontainers.image.documentation="https://github.com/AdguardTeam/AdGuardHome/wiki/" \
    org.opencontainers.image.licenses="GPL-3.0" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.source="https://github.com/AdguardTeam/AdGuardHome" \
    org.opencontainers.image.title="AdGuard Home" \
    org.opencontainers.image.url="https://adguard.com/en/adguard-home/overview.html" \
    org.opencontainers.image.vendor="AdGuard" \
    org.opencontainers.image.version=$VERSION

# Установим необходимые пакеты для обоих сервисов
RUN apk --no-cache add ca-certificates libcap tzdata dpkg dumb-init iptables wireguard-tools nodejs npm

# Подготовим директории для AdGuardHome
RUN mkdir -p /opt/adguardhome/conf /opt/adguardhome/work && \
    chown -R nobody: /opt/adguardhome

# Копируем бинарный файл AdGuardHome
COPY --chown=nobody:nogroup ./docker/AdGuardHome/AdGuardHome /opt/adguardhome/AdGuardHome

RUN setcap 'cap_net_bind_service=+eip' /opt/adguardhome/AdGuardHome

# Копируем и устанавливаем зависимости для wg-easy
COPY src /app
WORKDIR /app

# Устанавливаем зависимости
RUN npm install -g npm@latest && npm install

# Настраиваем порты для AdGuardHome
EXPOSE 53/tcp 53/udp 67/udp 68/udp 80/tcp 443/tcp 443/udp 853/tcp \
    853/udp 3000/tcp 3000/udp 5443/tcp 5443/udp 6060/tcp

# Настраиваем порты для wg-easy
EXPOSE 51820/udp 51821/tcp

# Установим переменные среды для wg-easy
ENV DEBUG=Server,WireGuard

# Запускаем оба сервиса через dumb-init
WORKDIR /opt/adguardhome/work

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/bin/sh", "-c", "/opt/adguardhome/AdGuardHome --no-check-update -c /opt/adguardhome/conf/AdGuardHome.yaml -w /opt/adguardhome/work & cd /app/src && node server.js"]
