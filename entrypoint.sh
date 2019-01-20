#!/bin/bash

set -e

curl -f https://api.wordpress.org/secret-key/1.1/salt/ >> /usr/src/wordpress/wp-secrets.php

exec "$@"
