#!/bin/bash

# Цвета для текста
TERRACOTTA='\033[38;5;208m'
LIGHT_BLUE='\033[38;5;117m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# Функции для форматирования текста
function show() {
    echo -e "${TERRACOTTA}${BOLD}$1${NC}"
}

function show_blue() {
    echo -e "${LIGHT_BLUE}$1${NC}"
}

function show_war() {
    echo -e "${RED}$1${NC}"
}

# ASCII-арт
echo "----------------------------------------------------------------------"
show '███╗   ██╗ ██████╗ ██████╗   █████╗ ████████╗███████╗██╗  ██╗ █████╗ '
show '████╗  ██║██╔═══██╗██╔══██╗ ██╔══██╗╚══██╔══╝██╔════╝██║ ██╔╝██╔══██╗'
show '██╔██╗ ██║██║   ██║██║   ██║███████║   ██║   █████╗  █████╔╝ ███████║'
show '██║╚██╗██║██║   ██║██║  ██║ ██╔══██║   ██║   ██╔══╝  ██╔═██╗ ██╔══██║'
show '██║ ╚████║╚██████╔╝██████╔╝ ██║  ██║   ██║   ███████╗██║  ██╗██║  ██║'
show '╚═╝  ╚═══╝ ╚═════╝ ╚═════╝  ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝'
echo "----------------------------------------------------------------------"

# Установка переменных версий
PROMETHEUS_VERSION="2.54.1"
NODE_EXPORTER_VERSION="1.8.2"
GRAFANA_VERSION="11.2.0"

# Установка Prometheus
show "Установка Prometheus..."
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
tar xvfz prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz > /dev/null
mv prometheus-$PROMETHEUS_VERSION.linux-amd64/prometheus /usr/bin/
rm -rf /tmp/prometheus*
mkdir -p /etc/prometheus /etc/prometheus/data

# Создание файла конфигурации для Prometheus
cat <<EOF> /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
EOF

# Настройка пользователя и прав для Prometheus
useradd -rs /bin/false prometheus
chown -R prometheus:prometheus /usr/bin/prometheus /etc/prometheus

# Создание и включение службы Prometheus
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
show "Установка Node Exporter..."
cd /tmp
wget -q https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
tar xvfz node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz > /dev/null
mv node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter /usr/bin/
rm -rf /tmp/node_exporter*

# Настройка пользователя и прав для Node Exporter
useradd -rs /bin/false node_exporter
chown node_exporter:node_exporter /usr/bin/node_exporter

# Создание и включение службы Node Exporter
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
show "Установка Grafana..."
apt-get install -y apt-transport-https software-properties-common wget > /dev/null
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list > /dev/null
apt-get update > /dev/null 2>&1
apt-get install -y adduser libfontconfig1 musl > /dev/null 2>&1
wget -q https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb
dpkg -i grafana_${GRAFANA_VERSION}_amd64.deb > /dev/null 2>&1
echo "export PATH=/usr/share/grafana/bin:$PATH" >> /etc/profile

# Настройка источника данных Prometheus в Grafana
show "Настройка источника данных Prometheus в Grafana..."

# Получение реального IP сервера
PROMETHEUS_IP=$(hostname -I | awk '{print $1}')

cat <<EOF> /etc/grafana/provisioning/datasources/prometheus.yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://$PROMETHEUS_IP:9090
EOF

# Запрос порта для Grafana
show_war "! Переключи раскладку клавиатуры на ENG"
show_war "! Для удаления введеных данных нажми CTRL+U"
echo -en "${TERRACOTTA}${BOLD}Введи порт для Grafana (по умолчанию 3000): ${NC}"
read GRAFANA_PORT
GRAFANA_PORT=${GRAFANA_PORT:-3000}

# Замена порта в файле конфигурации Grafana
sed -i "s/;http_port = 3000/http_port = $GRAFANA_PORT/" /etc/grafana/grafana.ini

# Запуск и включение Grafana
systemctl daemon-reload
systemctl enable grafana-server > /dev/null
systemctl start grafana-server > /dev/null

# Запрос основного сервера и добавление в Prometheus
echo -en "${TERRACOTTA}${BOLD}Введи имя основного сервера (на который сейчас происходит установка): ${NC}"
read MAIN_SERVER_NAME

# Получение реального IP сервера
SERVER_IP=$(hostname -I | awk '{print $1}')

cat <<EOF >> /etc/prometheus/prometheus.yml
  - job_name: "$MAIN_SERVER_NAME"
    static_configs:
      - targets: ["$SERVER_IP:9100"]
EOF

# Запрос дополнительных серверов для мониторинга
while true; do
    echo -en "${TERRACOTTA}${BOLD}Хочешь добавить еще один сервер для мониторинга? (Y/N): ${NC}" 
    read ADD_SERVER
    if [[ "$ADD_SERVER" =~ ^[Yy]$ ]]; then
        echo -en "${TERRACOTTA}${BOLD}Введи IP адрес сервера: ${NC}"
        read SERVER_IP
        echo -en "${TERRACOTTA}${BOLD}Введи имя сервера: ${NC}"
        read SERVER_NAME
        show "Добавлен сервер: $SERVER_NAME с IP: $SERVER_IP"

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
systemctl restart prometheus > /dev/null 2>&1
systemctl restart node_exporter > /dev/null 2>&1
systemctl restart grafana-server > /dev/null 2>&1
systemctl status prometheus > /dev/null 2>&1
systemctl status node_exporter > /dev/null 2>&1
systemctl status grafana-server > /dev/null 2>&1

# Получение реального IP сервера
SERVER_IP=$(hostname -I | awk '{print $1}')

# Вывод информации о завершении установки
echo -e "${TERRACOTTA}${BOLD}Установка завершена.\n"
echo -en "${TERRACOTTA}${BOLD}Теперь ты можешь мониторить состояние своих серверов в Grafana по адресу: ${NC}${LIGHT_BLUE}http://$SERVER_IP:$GRAFANA_PORT${NC}\n\n"
echo -en "${TERRACOTTA}${BOLD}Присоединяйся к Нодатеке, будем ставить ноды вместе! ${NC}${LIGHT_BLUE}https://t.me/cryptotesemnikov/778${NC}\n"
