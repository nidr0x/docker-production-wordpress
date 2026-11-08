#!/usr/bin/env bash

set -euo pipefail

image="${1:?usage: $0 IMAGE [PORT]}"
port="${2:-18080}"
run_id="${GITHUB_RUN_ID:-local-$$}"
network="wordpress-smoke-network-${run_id}"
db_container="wordpress-smoke-db-${run_id}"
app_container="wordpress-smoke-app-${run_id}"
secondary_app_container="wordpress-smoke-app-secondary-${run_id}"
tmp_dir="$(mktemp -d)"

cleanup() {
    docker rm -f "$app_container" "$secondary_app_container" "$db_container" >/dev/null 2>&1 || true
    docker network rm "$network" >/dev/null 2>&1 || true
    rm -rf "$tmp_dir"
}

show_logs() {
    docker logs "$db_container" 2>&1 || true
    docker logs "$app_container" 2>&1 || true
    docker logs "$secondary_app_container" 2>&1 || true
}

trap 'status=$?; if [ "$status" -ne 0 ]; then show_logs; fi; cleanup; exit "$status"' EXIT

docker network create "$network" >/dev/null

docker run --detach \
    --name "$db_container" \
    --network "$network" \
    --env MARIADB_ROOT_PASSWORD=smoke-root-password \
    --env MARIADB_DATABASE=wordpress \
    --env MARIADB_USER=wordpress \
    --env MARIADB_PASSWORD=smoke-wordpress-password \
    mariadb:11.8.9 >/dev/null

for attempt in $(seq 1 90); do
    if docker exec "$db_container" healthcheck.sh --connect --innodb_initialized >/dev/null 2>&1; then
        break
    fi

    if [ "$attempt" -eq 90 ]; then
        echo "MariaDB did not become ready" >&2
        exit 1
    fi

    sleep 2
done

docker run --detach \
    --name "$app_container" \
    --network "$network" \
    --publish "127.0.0.1:${port}:8080" \
    --env DB_HOST="$db_container" \
    --env DB_NAME=wordpress \
    --env DB_USER=wordpress \
    --env DB_PASSWORD=smoke-wordpress-password \
    --env TABLE_PREFIX=wp_ \
    --env DISABLE_WP_CRON=true \
    --env WP_DEBUG=false \
    "$image" >/dev/null

for attempt in $(seq 1 60); do
    if docker exec "$app_container" sh -c 'wget -qO- http://127.0.0.1:8080/ping' | grep -qx 'pong'; then
        break
    fi

    if [ "$attempt" -eq 60 ]; then
        echo "WordPress container did not expose the PHP-FPM ping endpoint" >&2
        exit 1
    fi

    sleep 2
done

docker run --detach \
    --name "$secondary_app_container" \
    --network "$network" \
    --env DB_HOST="$db_container" \
    --env DB_NAME=wordpress \
    --env DB_USER=wordpress \
    --env DB_PASSWORD=smoke-wordpress-password \
    --env TABLE_PREFIX=wp_secondary_ \
    --env DISABLE_WP_CRON=true \
    --env WP_DEBUG=false \
    "$image" >/dev/null

for attempt in $(seq 1 60); do
    if docker exec "$secondary_app_container" sh -c 'wget -qO- http://127.0.0.1:8080/ping' | grep -qx 'pong'; then
        break
    fi

    if [ "$attempt" -eq 60 ]; then
        echo "Secondary WordPress container did not become ready" >&2
        exit 1
    fi

    sleep 2
done

docker exec "$app_container" wp core install \
    --path=/usr/src/wordpress \
    --url="http://127.0.0.1:${port}" \
    --title="Smoke Test" \
    --admin_user=smokeadmin \
    --admin_password=smoke-admin-password \
    --admin_email=smoke@example.invalid \
    --skip-email >/dev/null 2>&1

docker exec "$secondary_app_container" wp core install \
    --path=/usr/src/wordpress \
    --url="http://127.0.0.1:${port}/secondary" \
    --title="Secondary Smoke Test" \
    --admin_user=smokeadmin \
    --admin_password=smoke-admin-password \
    --admin_email=smoke@example.invalid \
    --skip-email >/dev/null 2>&1

secret_hash="$(docker exec "$app_container" wp eval 'echo hash("sha256", wp_salt("auth"));' --path=/usr/src/wordpress)"
secondary_secret_hash="$(docker exec "$secondary_app_container" wp eval 'echo hash("sha256", wp_salt("auth"));' --path=/usr/src/wordpress)"
test -n "$secret_hash"
test "$secret_hash" != "$secondary_secret_hash"

docker restart "$app_container" >/dev/null

for attempt in $(seq 1 60); do
    if docker exec "$app_container" sh -c 'wget -qO- http://127.0.0.1:8080/ping' | grep -qx 'pong'; then
        break
    fi

    if [ "$attempt" -eq 60 ]; then
        echo "WordPress container did not recover after restart" >&2
        exit 1
    fi

    sleep 2
done

test "$secret_hash" = "$(docker exec "$app_container" wp eval 'echo hash("sha256", wp_salt("auth"));' --path=/usr/src/wordpress)"

docker exec "$app_container" wp theme install twentytwentyfive \
    --path=/usr/src/wordpress \
    --activate \
    --force >/dev/null 2>&1

status_body="$(docker exec "$app_container" sh -c 'wget -qO- http://127.0.0.1:8080/status')"
printf '%s\n' "$status_body" | grep -q '^pool:.*www'

curl --fail --silent --show-error \
    --dump-header "$tmp_dir/first.headers" \
    --output "$tmp_dir/first.body" \
    "http://127.0.0.1:${port}/"

curl --fail --silent --show-error \
    --dump-header "$tmp_dir/second.headers" \
    --output "$tmp_dir/second.body" \
    "http://127.0.0.1:${port}/"

grep -Eiq '^HTTP/[^ ]+ 200 ' "$tmp_dir/first.headers"
grep -Eiq '^HTTP/[^ ]+ 200 ' "$tmp_dir/second.headers"
grep -Eiq '^X-FastCGI-Cache:[[:space:]]*MISS' "$tmp_dir/first.headers"
grep -Eiq '^X-FastCGI-Cache:[[:space:]]*HIT' "$tmp_dir/second.headers"
test -s "$tmp_dir/first.body"
test -s "$tmp_dir/second.body"

for attempt in 1 2; do
    curl --fail --silent --show-error \
        --header 'Cookie: custom_private_session=smoke-test' \
        --dump-header "$tmp_dir/cookie-${attempt}.headers" \
        --output /dev/null \
        "http://127.0.0.1:${port}/"
    grep -Eiq '^X-FastCGI-Cache:[[:space:]]*BYPASS' "$tmp_dir/cookie-${attempt}.headers"
done

docker run --rm \
    --network "$network" \
    --env APP_HOST="$app_container" \
    --entrypoint /bin/sh \
    curlimages/curl:8.16.0 \
    -c 'for client_ip in 198.51.100.10 203.0.113.10; do for attempt in $(seq 1 15); do status="$(curl --silent --show-error --output /dev/null --write-out "%{http_code}" --header "CF-Connecting-IP: ${client_ip}" "http://${APP_HOST}:8080/wp-login.php")"; test "$status" != 429 || exit 1; done; done'

echo "Generic WordPress container smoke tests passed"
