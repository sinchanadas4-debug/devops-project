#!/bin/bash
set -e
dnf update -y
dnf install -y docker git
systemctl enable --now docker
usermod -aG docker ec2-user
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
mkdir -p /opt/app
chown ec2-user:ec2-user /opt/app