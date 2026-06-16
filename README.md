# AppStore Infrastructure

This repo manages the complete AppStore deployment:
Docker Compose, Keycloak, Monitoring (Prometheus, Loki, Grafana).

## Overview

```
appstore-backend   →  Python/FastAPI + Celery
appstore-frontend  →  React + Nginx
appstore-infra     →  this repo (Compose, Keycloak, Monitoring)
appstore-apps      →  Ansible app definitions
```

## Environments

| Environment | Compose files | URL |
|---|---|---|
| Dev (local) | `docker-compose.yml` + `docker-compose.dev.yml` | http://localhost:3000 |
| Staging | `docker-compose.yml` + `docker-compose.staging.yml` | https://\<staging-ip\> |
| Production | `docker-compose.yml` + `docker-compose.prod.yml` | https://\<prod-ip\> |

---

## From Zero to Running — Local Development

### Prerequisites

- Docker + Docker Compose v2
- Git
- Both app repos cloned into the same parent folder as this repo:
  ```
  dozilab/
  ├── appstore-backend/
  ├── appstore-frontend/
  └── appstore-infra/      ← this repo
  ```

### 1. Clone the repos

```bash
git clone git@github.com:your-org/appstore-backend.git
git clone git@github.com:your-org/appstore-frontend.git
git clone git@github.com:your-org/appstore-infra.git
cd appstore-infra
```

### 2. Configure environment

```bash
cp .env.example .env
```

Set these values in `.env` for local dev:

| Variable | Value |
|---|---|
| `SERVER_IP` | `localhost` |
| `DB_PASSWORD` | anything, e.g. `postgres` |
| `KEYCLOAK_ADMIN_PASSWORD` | anything, e.g. `admin` |
| `KEYCLOAK_URL` | `http://localhost:8080` |
| `ENCRYPTION_KEY` | generate (see below) |
| `ANSIBLE_SSH_KEY_PATH` | path to your SSH key |

Generate encryption key:
```bash
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

### 3. Generate Ansible SSH key (once)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/dozilab_ansible -N ""
```

### 4. Start

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

### 5. Set up Keycloak (first time only)

The `realm-export.json` is already checked in — Keycloak imports it automatically on first start.

Verify at http://localhost:8080 — login with `KEYCLOAK_ADMIN_USER` / `KEYCLOAK_ADMIN_PASSWORD` from `.env`.

If you make changes to the realm, export and commit them:
```bash
docker exec -it appstore-infra-keycloak-1 \
  /opt/keycloak/bin/kc.sh export \
  --dir /tmp/export \
  --realm Dozilab \
  --users realm_file

docker cp appstore-infra-keycloak-1:/tmp/export/Dozilab-realm.json ./keycloak/realm-export.json
git add keycloak/realm-export.json && git commit -m "update keycloak realm export"
```

### 6. Verify

| Service | URL |
|---|---|
| Frontend | http://localhost:3000 |
| Backend API | http://localhost:8000/docs |
| Keycloak | http://localhost:8080 |
| Database | localhost:5432 |
| Redis | localhost:6379 |

---

## From Zero to Running — Server Setup (Staging & Production)

See [heat/README.md](heat/README.md) for the full server setup guide using OpenStack Heat.

---

## Deployment

### Manual

```bash
# Staging
ssh -i ~/.ssh/appstore-staging ubuntu@<staging-ip> \
  "cd /opt/appstore && git pull && \
   docker compose -f docker-compose.yml -f docker-compose.staging.yml pull api celery-worker && \
   docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d api celery-worker"

# Production
ssh -i ~/.ssh/appstore-prod ubuntu@<prod-ip> \
  "cd /opt/appstore && git pull && \
   docker compose -f docker-compose.yml -f docker-compose.prod.yml pull api celery-worker && \
   docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d api celery-worker"
```

### Automatic via CI/CD

- Push to `main` → automatically deploys to Staging
- Push tag `v*` → requires approval → deploys to Production

See `.github/workflows/` in the backend and frontend repos.

---

## Useful Commands

```bash
# View logs
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f api

# Run database migrations
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec api alembic upgrade head

# Restart a single service
docker compose -f docker-compose.yml -f docker-compose.dev.yml restart api

# Stop everything (data is preserved)
docker compose -f docker-compose.yml -f docker-compose.dev.yml down

# Stop everything including volumes (WARNING: deletes the database)
docker compose -f docker-compose.yml -f docker-compose.dev.yml down -v
```

---

## Monitoring

| Service | Dev | Staging/Prod |
|---|---|---|
| Grafana | not active | http://\<ip\>:3000 |
| Prometheus | not active | internal only |
| Loki | not active | internal only |

Grafana datasources (Prometheus + Loki) are provisioned automatically on startup.
Dashboards in `monitoring/grafana/dashboards/` are loaded automatically.
