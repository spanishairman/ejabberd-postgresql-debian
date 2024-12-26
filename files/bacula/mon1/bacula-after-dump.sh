#!/bin/bash
systemctl start grafana-server.service
systemctl start prometheus-node-exporter.service
systemctl start prometheus.service
