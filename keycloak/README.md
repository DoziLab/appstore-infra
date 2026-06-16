# Keycloak Realm Export

Diese Datei enthält den vollständigen Keycloak-Realm als JSON.
Beim ersten Start von Keycloak wird der Realm automatisch importiert.

## Realm exportieren (nach manuellem Setup)

```bash
docker exec -it <keycloak-container> \
  /opt/keycloak/bin/kc.sh export \
  --dir /tmp/export \
  --realm Dozilab \
  --users realm_file

docker cp <keycloak-container>:/tmp/export/Dozilab-realm.json ./keycloak/realm-export.json
```

## Was im Realm konfiguriert sein muss

- **Realm Name**: `Dozilab`
- **Clients**:
  - `appstore-frontend` (Public Client, Valid Redirect URIs: `https://your-domain/*`)
  - `appstore-backend` (Bearer-only oder Confidential)
- **Roles**: `admin`, `lecturer`, `student` (je nach Bedarf)
- **Users**: Testnutzer für Dev/Staging

## realm-export.json

Die echte `realm-export.json` wird hier nach dem ersten manuellen Keycloak-Setup eingecheckt.
Solange diese Datei fehlt, muss Keycloak manuell konfiguriert werden (siehe README.md).
