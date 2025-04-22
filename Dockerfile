FROM curlimages/curl:8.13.0 AS download
ENTRYPOINT []
USER root

ENV WPCLI_DOWNLOAD_SHA256=a39021ac809530ea607580dbf93afbc46ba02f86b6cffd03de4b126ca53079f6
ENV WPCLI_VERSION=2.11.0

RUN curl -sfo /tmp/wp -L https://github.com/wp-cli/wp-cli/releases/download/v${WPCLI_VERSION}/wp-cli-${WPCLI_VERSION}.phar \
  && echo "$WPCLI_DOWNLOAD_SHA256 /tmp/wp" | sha256sum -c - \
  && chmod +x /tmp/wp

RUN set -x \
  && curl -f https://api.wordpress.org/secret-key/1.1/salt/ >> /tmp/wp-secrets.php

FROM public.ecr.aws/docker/library/alpine:3.21

LABEL Maintainer="Carlos R <nidr0x@gmail.com>" \
  Description="Slim WordPress image using Alpine Linux"

ENV WP_VERSION=6.8
ENV WP_LOCALE=en_US

ARG UID=82
ARG GID=82

RUN adduser -u $UID -D -S -G www-data www-data \
  && apk add --no-cache \
  php84 \
  php84-fpm \
  php84-mysqli \
  php84-json \
  php84-openssl \
  php84-curl \
  php84-simplexml \
  php84-ctype \
  php84-mbstring \
  php84-gd \
  php84-exif \
  nginx \
  supervisor \
  php84-zlib \
  php84-xml \
  php84-phar \
  php84-intl \
  php84-dom \
  php84-xmlreader \
  php84-zip \
  php84-opcache \
  php84-fileinfo \
  php84-iconv \
  less

RUN { \
  echo 'opcache.memory_consumption=128'; \
  echo 'opcache.interned_strings_buffer=8'; \
  echo 'opcache.max_accelerated_files=4000'; \
  echo 'opcache.revalidate_freq=2'; \
  echo 'opcache.fast_shutdown=1'; \
  } > /etc/php84/conf.d/opcache-recommended.ini

VOLUME /var/www/wp-content

WORKDIR /usr/src

RUN set -x \
  && mkdir /usr/src/wordpress \
  && chown -R $UID:$GID /usr/src/wordpress \
  && sed -i s/';cgi.fix_pathinfo=1/cgi.fix_pathinfo=0'/g /etc/php84/php.ini \
  && sed -i s/'expose_php = On/expose_php = Off'/g /etc/php84/php.ini \
  && ln -s /usr/sbin/php-fpm84 /usr/sbin/php-fpm \
  && ln -s /usr/bin/php84 /usr/bin/php

COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php84/php-fpm.d/zzz_custom_fpm_pool.conf
COPY config/php.ini /etc/php84/conf.d/zzz_custom_php.ini
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/nginx_includes/* /etc/nginx/includes/
COPY --chown=${UID} wp-config.php /usr/src/wordpress
COPY rootfs.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/rootfs.sh
COPY --from=download --chown=${UID} /tmp/wp /usr/local/bin/wp
COPY --from=download --chown=${UID} /tmp/wp-secrets.php /usr/src/wordpress/wp-secrets.php

RUN set -x \
  && chown -R $UID:$GID /etc/nginx \
  && chown -R $UID:$GID /var/lib/nginx \
  && chmod -R g+w /etc/nginx \
  && chmod g+wx /var/log/ \
  && ln -sf /dev/stderr /var/lib/nginx/logs/error.log \
  && deluser nginx \
  && rm -rf /tmp/* \
  && chmod 660 /usr/src/wordpress/wp-config.php \
  && sed -i '1s/^/<?php \n/' /usr/src/wordpress/wp-secrets.php \
  && rm -rf /var/www/localhost

USER ${UID}

RUN set -x \
  && wp core download --path=/usr/src/wordpress --version="${WP_VERSION}" --skip-content --locale="${WP_LOCALE}"

WORKDIR /var/www/wp-content

EXPOSE 8080

STOPSIGNAL SIGQUIT

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
