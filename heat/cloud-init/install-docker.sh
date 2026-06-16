#!/usr/bin/env bash
# Gemeinsames Setup: Docker + grundlegende Tools installieren
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -q
apt-get install -yq \
    ca-certificates \
    curl \
    gnupg \
    git \
    jq

# Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -q
apt-get install -yq docker-ce docker-ce-cli containerd.io docker-compose-plugin

usermod -aG docker ubuntu
systemctl enable --now docker
