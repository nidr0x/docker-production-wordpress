# rootless WordPress Docker Container

This Dockerfile installs WordPress 6.x, along with the latest [wp-cli](https://wp-cli.org/) (used to download the WordPress as well), supervisor, nginx 1.24, and PHP-FPM 8.1 (on-demand PM) on Alpine Linux. It's designed as a rootless image, for heavy-load production sites and is currently being used in multiple environments without any issues.

The `wp-config.php` file included in this container is configured to use environmental variables, making management much easier. The nginx configuration has also been heavily tweaked and optimized. Additionally, the container runs a system cron instead of WP cron, as the latter is not very reliable.

Also, it has a script managed by `supervisor` process which copies all data automatically from `/data` and put into `/usr/src/wordpress` if you want to add files to the root folder, like `robots.txt`.

The current image size is around 80 MB, and the goal of this project is to make it even smaller.

## Prerequisites

Before using this Docker image, make sure you have the following software installed:

- Docker
- docker-compose

## Usage

To obtain this Docker image, simply pull it from the GHCR.

```
    $ docker pull ghcr.io/nidr0x/wordpress:latest
```

## Usage with Docker-Compose

If you wish to spin up a running environment, you can use docker-compose.

```
    $ docker-compose up -d
```

## Contribution

If you would like to contribute to this project, feel free to open an issue or submit a pull request on GitHub.

## References

* https://github.com/docker-library/wordpress
* https://codeable.io/wordpress-developers-intro-to-docker-part-one/
* https://codeable.io/wordpress-developers-intro-to-docker-part-two/
* https://github.com/TrafeX/docker-php-nginx/
* https://hub.docker.com/_/wordpress/
