# Rootless WordPress Docker Container

A WordPress container stack based on Alpine Linux for production use.

## Stack

- WordPress 7.1, downloaded with `wp-cli`
- PHP-FPM 8.5 with the ondemand process manager
- Nginx
- s6-overlay and cron
- MariaDB via `docker-compose.yml`

## Prerequisites

- Docker Engine
- Docker Compose v2 (`docker compose ...`)

## Set up the environment

Create `.env` from the sample, then set the credentials and hostnames:

```bash
cp .env.example .env
```

## Compose profiles

### Local profile

Use this profile for development or debugging. WordPress is available at `http://127.0.0.1:8081`.

```bash
docker compose up -d db wordpress
```

MariaDB remains private on this default Docker Compose path.

### Production profile

This profile starts the full stack, including Traefik:

```bash
docker compose up -d
```

### Apple Container profile

Use this profile with `container-compose`:

```bash
container-compose up -d -f container-compose.yml --env-file .env db wordpress
```

This profile includes the Apple Container compatibility workarounds. It publishes MariaDB on host port
`3306` because `container-compose` requires that path for WordPress-to-DB connectivity in this runtime.
Start the services together with the command above. Detached single-service startup is not supported here.

Notes:

- This Compose file creates and manages the `traefik` and `backend` networks.
- The custom DB image applies the MariaDB tuning from `mariadb.Dockerfile` and remains compatible with Apple `container-compose`.
- Set `DOMAIN`, `LETSENCRYPT_EMAIL`, and `LETSENCRYPT_CA_SERVER` in `.env` before using the Traefik profile.
- Point `LETSENCRYPT_CA_SERVER` at the Let's Encrypt staging directory while testing, then at the production directory before go-live.

## Important Paths

- `./wp-config.php`: environment-driven WordPress config
- `./config/nginx.conf`: main Nginx config
- `./config/nginx_includes/include.conf`: extra hardening and security rules
- `./config/my.cnf`: MariaDB tuning

## Contributing

Open an issue or pull request with reproduction steps and the expected behavior.

## References

- https://github.com/docker-library/wordpress
- https://github.com/TrafeX/docker-php-nginx/
- https://hub.docker.com/_/wordpress/
