# Rootless WordPress Docker Container

Production-oriented WordPress container stack based on Alpine Linux.

## Stack

- WordPress 7.0 (downloaded by `wp-cli`)
- PHP-FPM 8.5 (ondemand process manager)
- Nginx
- s6-overlay + cron
- MariaDB (via `docker-compose.yml`)

## Prerequisites

- Docker Engine
- Docker Compose v2 (`docker compose ...`)

## Environment Setup

Copy the sample environment and adjust credentials and hostnames:

```bash
cp .env.example .env
```

## Compose Run Profiles

### Local profile (app + database only)

Use this during development/debugging and access WordPress at `http://127.0.0.1:8081`.

```bash
docker compose up -d db wordpress
```

MariaDB stays private in this default Docker Compose path.

### Production profile (includes Traefik)

Use this to run the full stack from this repository:

```bash
docker compose up -d
```

### Apple Container profile

Use this when running through `container-compose`:

```bash
container-compose up -d -f container-compose.yml --env-file .env db wordpress
```

This profile keeps the Apple Container compatibility workarounds.
MariaDB is intentionally published on host port `3306` in this profile because `container-compose`
needs that path for WordPress-to-DB connectivity in this runtime.
Use the multi-service startup command above; detached single-service startup is not the supported path here.

Notes:

- This compose file creates and manages the `traefik` and `backend` networks itself.
- MariaDB tuning is baked into the custom DB image via `mariadb.Dockerfile`, which keeps it compatible with Apple `container-compose`.
- Set `DOMAIN`, `LETSENCRYPT_EMAIL`, and `LETSENCRYPT_CA_SERVER` in `.env` before using the Traefik-enabled profile.
- `LETSENCRYPT_CA_SERVER` should point at Let’s Encrypt staging while testing and the production directory before go-live.

## Important Paths

- `/Users/carlos/work-dir/docker-production-wordpress/wp-config.php`: environment-driven WordPress config
- `/Users/carlos/work-dir/docker-production-wordpress/config/nginx.conf`: main Nginx config
- `/Users/carlos/work-dir/docker-production-wordpress/config/nginx_includes/include.conf`: extra hardening and security rules
- `/Users/carlos/work-dir/docker-production-wordpress/config/my.cnf`: MariaDB tuning

## Contribution

Open an issue or pull request with reproduction steps and expected behavior.

## References

- https://github.com/docker-library/wordpress
- https://github.com/TrafeX/docker-php-nginx/
- https://hub.docker.com/_/wordpress/
