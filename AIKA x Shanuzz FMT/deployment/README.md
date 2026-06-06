# Deployment Guide

## Architecture

```
Cloudflare
  └── aika-shuz.fyi (proxied)
        ├── fmt.aika-shuz.fyi → Traefik → Flutter web container (port 80)
        └── pb.aika-shuz.fyi  → Traefik → PocketBase container (port 8090)
```

## DNS (Cloudflare)

Add A records in Cloudflare dashboard:
| Type | Name | Value | Proxy |
|------|------|-------|-------|
| A | `fmt` | 154.84.215.26 | ✅ Proxied |
| A | `pb` | 154.84.215.26 | ✅ Proxied |

## PocketBase (Coolify)

1. Create service → Docker → single container
2. Image: `pocketbase/pocketbase:latest`
3. Persistent volume mount: `/pb_data`
4. Port mapping: `8090:8090` (internal, exposed via Traefik)
5. Health check: `wget -qO- http://127.0.0.1:8090/api/health`
6. Add Traefik labels:
   - `traefik.enable=true`
   - `traefik.http.routers.fmt-pb.rule=Host(\`pb.aika-shuz.fyi\`)`
   - `traefik.http.routers.fmt-pb.entrypoints=https`
   - `traefik.http.routers.fmt-pb.tls=true`
   - `traefik.http.routers.fmt-pb.tls.certresolver=letsencrypt`
   - `traefik.http.services.fmt-pb.loadbalancer.server.port=8090`
   - `traefik.docker.network=coolify`
7. After first start: go to `https://pb.aika-shuz.fyi/_/` and create admin
8. Create the `entries` collection (same schema as in `docs/plans/2026-06-06-pocketbase-migration.md`)
9. Create users via Admin UI or the app

## Flutter Web App (Coolify)

1. Create service → Dockerfile (uses repo root Dockerfile)
2. No ports needed (Traefik routes to internal nginx port 80)
3. Build env: none needed (Flutter build inside Docker, PocketBase URL is compile-time)
4. Add Traefik labels:
   - `traefik.enable=true`
   - `traefik.http.routers.fmt-app.rule=Host(\`fmt.aika-shuz.fyi\`)`
   - `traefik.http.routers.fmt-app.entrypoints=https`
   - `traefik.http.routers.fmt-app.tls=true`
   - `traefik.http.routers.fmt-app.tls.certresolver=letsencrypt`
   - `traefik.http.services.fmt-app.loadbalancer.server.port=80`
   - `traefik.docker.network=coolify`

## Local Build (Windows dev machine)

```powershell
# Build the Flutter web app
flutter build web --release
```

The Dockerfile in the repo builds from source, so Coolify handles the build.
