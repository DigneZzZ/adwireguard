# Используем node:18-alpine для установки зависимостей
FROM node:18-alpine AS build

# Устанавливаем зависимости для Node.js
RUN npm install -g npm@latest

# Копируем исходный код для установки зависимостей
COPY src /app
WORKDIR /app

# Устанавливаем зависимости
RUN npm ci --omit=dev

# Финальный образ
FROM alpine:3.18

# Устанавливаем необходимые пакеты
RUN apk --no-cache add ca-certificates libcap tzdata dpkg dumb-init iptables wireguard-tools curl nodejs npm

# Копируем зависимости из build stage
COPY --from=build /app /app
COPY --from=build /app/node_modules /app/node_modules

# Загружаем последнюю версию AdGuardHome
RUN curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | \
    grep "browser_download_url.*linux_amd64.tar.gz" | \
    cut -d '"' -f 4 | \
    xargs curl -L -o AdGuardHome_linux_amd64.tar.gz && \
    tar -xzvf AdGuardHome_linux_amd64.tar.gz && \
    mv AdGuardHome /opt/adguardhome && \
    rm AdGuardHome_linux_amd64.tar.gz

# Устанавливаем права на выполнение для AdGuardHome
RUN setcap 'cap_net_bind_service=+eip' /opt/adguardhome/AdGuardHome

# Настраиваем рабочую директорию и запускаем контейнер
WORKDIR /opt/adguardhome/work

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/bin/sh", "-c", "/opt/adguardhome/AdGuardHome --no-check-update -c /opt/adguardhome/conf/AdGuardHome.yaml -w /opt/adguardhome/work & cd /app && npm start"]
