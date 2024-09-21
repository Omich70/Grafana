#!/bin/bash

echo "----------------------------------------------------------------------"
TERRACOTTA='\033[38;5;208m'
NC='\033[0m'

# Вывод терракотового текста
function show() {
    echo -e "${TERRACOTTA}$1${NC}"
}

show '███╗   ██╗ ██████╗ ██████╗  █████╗ ████████╗███████╗██╗  ██╗ █████╗ '
show '████╗  ██║██╔═══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝██║ ██╔╝██╔══██╗'
show '██╔██╗ ██║██║   ██║██║  ██║███████║   ██║   █████╗  █████╔╝ ███████║'
show '██║╚██╗██║██║   ██║██║  ██║██╔══██║   ██║   ██╔══╝  ██╔═██╗ ██╔══██║'
show '██║ ╚████║╚██████╔╝██████╔╝██║  ██║   ██║   ███████╗██║  ██╗██║  ██║'
show '╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝'
echo "----------------------------------------------------------------------"

# Установка переменных
PROMETHEUS_VERSION="2.54.1"
NODE_EXPORTER_VERSION="1.8.2"
GRAFANA_VERSION="11.2.0"

# Установка Prometheus
echo "Установка Prometheus..."
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
tar xvfz prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
mv prometheus-$PROMETHEUS_VERSION.linux-amd64/prometheus /usr/bin/
rm -rf /tmp/prometheus*
mkdir -p /etc/prometheus
mkdir -p /etc/prometheus/data

cat <<EOF> /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
EOF

useradd -rs /bin/false prometheus
chown prometheus:prometheus /usr/bin/prometheus
chown prometheus:prometheus /etc/prometheus
chown prometheus:prometheus /etc/prometheus/prometheus.yml
chown prometheus:prometheus /etc/prometheus/data

cat <<EOF> /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Server
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
ExecStart=/usr/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/etc/prometheus/data

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus

# Установка Node Exporter
echo "Установка Node Exporter..."
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
tar xvfz node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
mv node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter /usr/bin/
rm -rf /tmp/node_exporter*

useradd -rs /bin/false node_exporter
chown node_exporter:node_exporter /usr/bin/node_exporter

cat <<EOF> /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

# Установка Grafana
echo "Установка Grafana..."
apt-get install -y apt-transport-https software-properties-common wget
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y adduser libfontconfig1 musl
wget https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb
dpkg -i grafana_${GRAFANA_VERSION}_amd64.deb
echo "export PATH=/usr/share/grafana/bin:$PATH" >> /etc/profile

# Настройка источника данных Prometheus в Grafana
echo "Настройка источника данных Prometheus в Grafana..."
read -p "Введите IP адрес вашего сервера Prometheus (по умолчанию 127.0.0.1): " PROMETHEUS_IP
PROMETHEUS_IP=${PROMETHEUS_IP:-127.0.0.1}

cat <<EOF> /etc/grafana/provisioning/datasources/prometheus.yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://$PROMETHEUS_IP:9090
EOF

# Запрос порта для Grafana
read -p "Введи порт для Grafana (по умолчанию 3000): " GRAFANA_PORT
GRAFANA_PORT=${GRAFANA_PORT:-3000}

# Запуск и включение Grafana
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

# Запрос дополнительных серверов
while true; do
    read -p "Хочешь добавить еще один сервер для мониторинга? (Y/N): " ADD_SERVER
    if [[ "$ADD_SERVER" == "Y" ]]; then
        read -p "Введи IP адрес сервера: " SERVER_IP
        read -p "Введи имя сервера: " SERVER_NAME
        echo "Добавлен сервер: $SERVER_NAME с IP: $SERVER_IP"

        # Добавление конфигурации для нового сервера в prometheus.yml
        cat <<EOF >> /etc/prometheus/prometheus.yml
  - job_name: "$SERVER_NAME"
    static_configs:
      - targets: ["$SERVER_IP:9100"]
EOF

    else
        break
    fi
done

# Проверка статуса сервисов
systemctl status prometheus --no-pager
systemctl status node_exporter --no-pager
systemctl status grafana-server --no-pager

# Получение реального IP сервера
SERVER_IP=$(hostname -I | awk '{print $1}')

# Вывод ссылки на Grafana
echo "Установка завершена."
echo "Запусти второй скрипт на всех добавленных серверах."
echo "Теперь ты можешь мониторить состояние своих серверов в Grafana по адресу: http://$SERVER_IP:$GRAFANA_PORT"
echo ""
echo "Присоединяйся к Нодатеке, будем ставить ноды вместе!  https://t.me/cryptotesemnikov/778"
