# Server Setup Guide

This guide explains how to create the three AppStore servers on OpenStack.

## Prerequisites

- OpenStack CLI installed and configured (`clouds.yaml` in place)
- Access to the DHBW OpenStack project
- Git

---

## 1. GitHub Runner

The runner executes all CI/CD jobs. Create it once and leave it running.

**Generate SSH key:**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/dozilab-github-runner -N ""
```

> The runner setup uses the **x86_64 (amd64)** binary — make sure your OpenStack flavor is x86_64.

**Get a runner registration token:**

The runner must be registered at the **organisation level** so all repos (backend, frontend, infra) can use it without each repo needing its own runner.

1. Go to your GitHub Organisation page (e.g. `github.com/dozilab`)
2. Click **Settings** (organisation settings, not a repo)
3. In the left sidebar: **Actions → Runners**
4. Click **New self-hosted runner**
5. Select **Linux** → copy the token shown under "Configure" — it looks like `AXXXXXXXXXXXXXXXXXXXXXXXXX`

> The token expires after 1 hour. If the stack creation takes longer, generate a new token and re-run the stack update.

> **Important:** Do not use a repo-level runner token (Settings inside a repo). That would only work for that one repo.

**Create the stack:**
```bash
openstack stack create dozilab-github-runner \
  -t heat/runner.yaml \
  --parameter public_key="$(cat ~/.ssh/dozilab-github-runner.pub)" \
  --parameter github_org=dozilab \
  --parameter github_runner_token=<token-from-github> \
  --parameter runner_labels="self-hosted"
```

**Get the IP and verify:**
```bash
openstack stack output show dozilab-github-runner floating_ip -f value -c output_value
# Wait ~5 minutes, then SSH in:
ssh -i ~/.ssh/dozilab-github-runner ubuntu@<floating-ip>
# Check runner status:
sudo /home/ubuntu/actions-runner/svc.sh status
```

---

## 2. Staging Server

**Generate SSH key:**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/dozilab-appstore-staging -N ""
```

**Generate an encryption key:**
```bash
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
# Save this value — you will need it again if you recreate the server
```

**Create the stack:**
```bash
openstack stack create appstore-staging \
  -t heat/staging.yaml \
  --parameter public_key="$(cat ~/.ssh/dozilab-appstore-staging.pub)" \
  --parameter github_org=dozilab \
  --parameter db_password=<secure-password> \
  --parameter encryption_key=<generated-above> \
  --parameter keycloak_admin_password=<secure-password> \
  --parameter grafana_admin_password=<secure-password>
```

**Get the IP:**
```bash
FIP=$(openstack stack output show appstore-staging floating_ip -f value -c output_value)
echo $FIP
```

**Wait for cloud-init to finish (~5 minutes):**
```bash
# Watch the console log for the ready marker:
openstack console log show appstore-staging | grep DOZILAB_READY
```

**Copy the Ansible SSH key:**
```bash
scp -i ~/.ssh/dozilab-appstore-staging ~/.ssh/dozilab_ansible ubuntu@$FIP:~/.ssh/dozilab_ansible
```

**Start the application:**
```bash
ssh -i ~/.ssh/dozilab-appstore-staging ubuntu@$FIP
cd /opt/appstore
docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d
```

**Update Keycloak redirect URIs:**

After the server is up, log in to the Keycloak Admin Console and update the `appstore-frontend` client with the correct server IP:

1. Open `https://<floating-ip>:8443/admin`
2. Login with `KEYCLOAK_ADMIN_USER` / `KEYCLOAK_ADMIN_PASSWORD` from `.env`
3. Go to **Clients → appstore-frontend → Settings**
4. Update the following fields with your floating IP:
   - **Valid redirect URIs**: `https://<floating-ip>/*`
   - **Valid post logout redirect URIs**: `https://<floating-ip>/*`
   - **Web origins**: `https://<floating-ip>`
5. Click **Save**

> This step is required every time you recreate the server with a new floating IP.

**Verify:**
```bash
# Check all containers are running:
docker compose -f docker-compose.yml -f docker-compose.staging.yml ps

# Run database migrations:
docker compose -f docker-compose.yml -f docker-compose.staging.yml exec api alembic upgrade head
```

> **Note:** nginx depends on Keycloak being healthy before it starts. Keycloak takes ~2-3 minutes on first boot. Once all other containers are running, start nginx manually:
> ```bash
> sudo docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d nginx
> ```

**Access:**
| Service | URL |
|---|---|
| Frontend | `https://<floating-ip>` |
| Keycloak | `https://<floating-ip>:8443` |
| Grafana | `http://<floating-ip>:3000` |

---

## 3. Production Server

Same as staging — use separate keys and passwords.

**Generate SSH key:**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/dozilab-appstore-prod -N ""
```

**Create the stack:**
```bash
openstack stack create appstore-prod \
  -t heat/prod.yaml \
  --parameter public_key="$(cat ~/.ssh/dozilab-appstore-prod.pub)" \
  --parameter github_org=dozilab \
  --parameter db_password=<secure-password> \
  --parameter encryption_key=<generated-key> \
  --parameter keycloak_admin_password=<secure-password> \
  --parameter grafana_admin_password=<secure-password>
```

Follow the same steps as staging to get the IP, copy the Ansible key, and start the application — but use `docker-compose.prod.yml` instead.

---

## GitHub Secrets

After all three servers are running, add these secrets to the backend and frontend repos:

**Settings → Secrets and variables → Actions:**

| Secret | Value |
|---|---|
| `APPSTORE_SERVER_SSH_KEY` | Contents of `~/.ssh/dozilab-github-runner` (private key) |
| `STAGING_SERVER_HOST` | Staging floating IP |
| `PROD_SERVER_HOST` | Production floating IP |

**Frontend repo only:**

| Secret | Value |
|---|---|
| `VITE_KEYCLOAK_URL` | `https://<staging-ip>:8443` |
| `VITE_KEYCLOAK_REALM` | `Dozilab` |
| `VITE_KEYCLOAK_CLIENT_ID` | `appstore-frontend` |

---

## Manual Docker Login on the Server

The CI/CD pipeline logs in to ghcr.io automatically on every deploy. For the **first manual start** or when pulling images manually, you need to log in once on the server.

**Generate a GitHub Personal Access Token (Classic):**

1. Go to GitHub → Settings → Developer settings → Personal access tokens → **Tokens (classic)**
2. Click **Generate new token (classic)**
3. Set a name, e.g. `appstore-staging-ghcr-read`
4. Select scope: **`read:packages`** only
5. Click **Generate token** → copy the token immediately (shown only once)

**Log in on the server:**

```bash
ssh -i ~/.ssh/dozilab-appstore-staging ubuntu@<staging-ip>

echo "<your-token>" | docker login ghcr.io -u <your-github-username> --password-stdin
```

**Pull and start manually:**

```bash
cd /opt/appstore
docker compose -f docker-compose.yml -f docker-compose.staging.yml pull
docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d
docker compose -f docker-compose.yml -f docker-compose.staging.yml exec api alembic upgrade head
```

> After this first manual login, all subsequent deploys via CI/CD log in automatically using `GITHUB_TOKEN` — no manual token needed again.

---

## Deleting a Server

```bash
openstack stack delete appstore-staging --yes
```

> **Note:** This deletes the VM and all its data including the database. Make sure to back up any important data first.
