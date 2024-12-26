#!/bin/bash
# Пример pg_dump со сжатием:
# sudo -u postgres pg_dump -d ejabberd | gzip > /media/backup/dump/ejabberd.sql.gz
# Мы делаем без сжатия, так как сжимать файлы будет bacula
systemctl stop grafana-server.service
systemctl stop prometheus.service
systemctl stop prometheus-node-exporter.service
