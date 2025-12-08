FROM curlimages/curl:8.16.0 AS download
ENTRYPOINT []
USER root

ENV WPCLI_DOWNLOAD_SHA256=ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c

ENV WPCLI_VERSION=2.12.0

RUN curl -sfo /tmp/wp -L https://github.com/wp-cli/wp-cli/releases/download/v${WPCLI_VERSION}/wp-cli-${WPCLI_VERSION}.phar \
  && echo "$WPCLI_DOWNLOAD_SHA256 /tmp/wp" | sha256sum -c - \
  && chmod +x /tmp/wp

RUN set -x \
  && curl -f https://api.wordpress.org/secret-key/1.1/salt/ >> /tmp/wp-secrets.php

FROM public.ecr.aws/docker/library/alpine:3.23

LABEL Maintainer="Carlos R <nidr0x@gmail.com>" \
  Description="Slim WordPress image using Alpine Linux"

ENV WP_VERSION=6.9
ENV WP_LOCALE=en_US

ARG UID=82
ARG GID=82

RUN adduser -u $UID -D -S -G www-data www-data \
  && apk add --no-cache \
  php85 \
  php85-fpm \
  php85-mysqli \
  php85-json \
  php85-openssl \
  php85-curl \
  php85-simplexml \
  php85-ctype \
  php85-mbstring \
  php85-gd \
  php85-exif \
  nginx \
  supervisor \
  php85-zlib \
  php85-xml \
  php85-phar \
  php85-intl \
  php85-dom \
  php85-xmlreader \
  php85-zip \
  php85-fileinfo \
  php85-iconv \
  less

RUN { \
  echo 'opcache.memory_consumption=128'; \
  echo 'opcache.interned_strings_buffer=8'; \
  echo 'opcache.max_accelerated_files=4000'; \
  echo 'opcache.revalidate_freq=2'; \
  echo 'opcache.fast_shutdown=1'; \
  } > /etc/php85/conf.d/opcache-recommended.ini

VOLUME /var/www/wp-content

WORKDIR /usr/src

RUN set -x \
  && mkdir /usr/src/wordpress \
  && chown -R $UID:$GID /usr/src/wordpress \
  && sed -i s/';cgi.fix_pathinfo=1/cgi.fix_pathinfo=0'/g /etc/php85/php.ini \
  && sed -i s/'expose_php = On/expose_php = Off'/g /etc/php85/php.ini \
  && ln -s /usr/sbin/php-fpm85 /usr/sbin/php-fpm \
  && ln -s /usr/bin/php85 /usr/bin/php

COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php85/php-fpm.d/zzz_custom_fpm_pool.conf
COPY config/php.ini /etc/php85/conf.d/zzz_custom_php.ini
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
