#!/bin/bash

# Сообщение перед удалением
echo "Удаление скрипта и восстановление системы..."

# Восстановление исходных файлов или конфигураций
# Добавьте команды для восстановления файлов, если вы их изменяли
# Например, восстановление конфигурационных файлов Prometheus, Node Exporter или Grafana

# Пример: восстановление конфигурационного файла Prometheus
if [ -f "/etc/prometheus/prometheus.yml.bak" ]; then
    mv /etc/prometheus/prometheus.yml.bak /etc/prometheus/prometheus.yml
    echo "Файл конфигурации Prometheus восстановлен."
fi

# Отключение сервисов и их удаление
systemctl stop prometheus
systemctl disable prometheus
rm /etc/systemd/system/prometheus.service
echo "Сервис Prometheus удален."

systemctl stop node_exporter
systemctl disable node_exporter
rm /etc/systemd/system/node_exporter.service
echo "Сервис Node Exporter удален."

systemctl stop grafana-server
systemctl disable grafana-server
rm /etc/systemd/system/grafana-server.service
echo "Сервис Grafana удален."

# Удаление пакетов, если они были установлены
apt-get remove --purge grafana -y
apt-get remove --purge prometheus -y
apt-get remove --purge node_exporter -y
apt-get autoremove -y
echo "Пакеты Grafana, Prometheus, и Node Exporter удалены."

# Удаление установленных директорий
rm -rf /etc/prometheus
rm -rf /etc/grafana

# Удаление самого скрипта
SCRIPT_PATH=$(realpath "$0")
rm "$SCRIPT_PATH"

echo "Скрипт удален."

exit 0
