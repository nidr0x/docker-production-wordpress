# Rootless WordPress Docker Container

Production-oriented WordPress container stack based on Alpine Linux.

## Stack

- WordPress 6.x (downloaded by `wp-cli`)
- PHP-FPM 8.5 (ondemand process manager)
- Nginx
- Supervisor + cron
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

### Production profile (includes Traefik)

Use this to run the full stack from this repository:

```bash
docker compose up -d
```

Notes:

- This compose file expects an external Docker network named `traefik`.
- ACME in `docker-compose.yml` is currently configured for Let’s Encrypt staging.
  Switch to production CA settings before go-live.

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
