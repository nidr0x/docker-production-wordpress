<div align="center">
  <h1>Rootless WordPress Docker Container</h1>
  <p>An Alpine-based WordPress image that runs as an unprivileged user, with Nginx, PHP-FPM, and Compose examples for MariaDB and Traefik.</p>
  <p>
    <a href="https://github.com/nidr0x/docker-production-wordpress/actions/workflows/ci.yml"><img src="https://github.com/nidr0x/docker-production-wordpress/actions/workflows/ci.yml/badge.svg?branch=master" alt="CI"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  </p>
</div>

## Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Run modes](#run-modes)
  - [Local access](#local-access)
  - [Traefik](#traefik)
  - [Apple Container](#apple-container)
- [Optional Redis object cache](#optional-redis-object-cache)
- [Project layout](#project-layout)
- [Contributing](#contributing)
- [License](#license)
- [References](#references)

## Overview

- WordPress 7.1.2 by default, downloaded with WP-CLI
- PHP-FPM 8.5 and Nginx
- MariaDB with project-specific configuration
- Traefik for HTTPS routing when using the full Compose stack

If authentication keys are omitted, WordPress generates a per-installation secret in the database. The first upgrade from the previous image signs users out once because its keys were generated during the image build. Keep the database volume when recreating the container; replacing it signs users out again.

## Requirements

- Docker Engine
- Docker Compose v2 (`docker compose ...`)
- For the Apple Container setup: `container-compose`

## Quick start

Copy the sample environment file and replace its example database passwords before starting:

```bash
cp -n .env.example .env
```

For local access, start WordPress and MariaDB:

```bash
docker compose up -d db wordpress
```

Open [http://127.0.0.1:8081](http://127.0.0.1:8081).

## Run modes

### Local access

The command above publishes WordPress on `127.0.0.1:8081`. MariaDB stays on the private Compose network.

### Traefik

The default Compose file starts the full stack, including Traefik:

```bash
docker compose up -d
```

Before starting it, set `DOMAIN`, `LETSENCRYPT_EMAIL`, and `LETSENCRYPT_CA_SERVER` in `.env`. Point the domain at the server and allow inbound ports 80 and 443. Use the Let's Encrypt staging directory while testing; switch to the production directory before go-live.

### Apple Container

Use the compatibility Compose file with `container-compose`:

```bash
container-compose up -d -f container-compose.yml --env-file .env db wordpress
```

Start both services together. MariaDB is published on host loopback port `3306` for this runtime's WordPress-to-database connectivity; remote hosts cannot connect through this binding. Detached single-service startup is not supported here.

## Optional Redis object cache

The image uses WordPress's default per-request object cache and does not include Redis. To use an external persistent cache:

1. Mount a compatible Redis object-cache drop-in at `wp-content/object-cache.php`.
2. Set `WP_CACHE=true` and the required `WP_REDIS_*` variables from `.env.example`.
3. Use a dedicated Redis database or prefix for each WordPress installation.

The existing `wp-content` mount is the drop-in location. The drop-in must support the PHP extensions available in the image.

## Project layout

| Path | Purpose |
| --- | --- |
| `docker-compose.yml` | Standard Compose stack with Traefik |
| `container-compose.yml` | Apple Container-compatible stack |
| `Dockerfile` | WordPress, PHP-FPM, and Nginx image |
| `mariadb.Dockerfile` | MariaDB image build |
| `wp-config.php` | Environment-driven WordPress configuration |
| `config/nginx.conf` | Main Nginx configuration |
| `config/nginx_includes/` | Additional Nginx security rules |
| `config/my.cnf` | MariaDB configuration |
| `scripts/` | Container smoke-check and version scripts |

## Contributing

Open an issue or pull request with reproduction steps and the expected behavior.

## License

This project is licensed under the [MIT License](LICENSE).

## References

- [WordPress Docker image source](https://github.com/docker-library/wordpress)
- [TrafeX Docker PHP-Nginx](https://github.com/TrafeX/docker-php-nginx/)
- [Official WordPress image on Docker Hub](https://hub.docker.com/_/wordpress/)
