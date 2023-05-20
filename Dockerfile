FROM alpine:3.18 AS download

ENV WPCLI_DOWNLOAD_SHA256 bbf096bccc6b1f3f1437e75e3254f0dcda879e924bbea403dff3cfb251d4e468

RUN apk add --no-cache \
    curl \ 
    coreutils

RUN set -x \
    && curl -sfo /tmp/wp -L https://github.com/wp-cli/wp-cli/releases/download/v2.7.1/wp-cli-2.7.1.phar \
    && echo "$WPCLI_DOWNLOAD_SHA256 /tmp/wp" | sha256sum -c -

RUN set -x \
    && curl -f https://api.wordpress.org/secret-key/1.1/salt/ >> /tmp/wp-secrets.php

FROM alpine:3.18

LABEL Maintainer="Carlos R <nidr0x@gmail.com>" \
      Description="Slim WordPress image using Alpine Linux"

ENV WP_VERSION 6.2.1
ENV WP_LOCALE en_US

ARG UID=82
ARG GID=82

RUN adduser -u $UID -D -S -G www-data www-data \
    && apk add --no-cache \
       php81 \
       php81-fpm \
       php81-mysqli \
       php81-json \
       php81-openssl \
       php81-curl \
       php81-simplexml \
       php81-ctype \
       php81-mbstring \
       php81-gd \
       php81-exif \
       nginx \
       supervisor \
       php81-zlib \
       php81-xml \
       php81-phar \
       php81-intl \
       php81-dom \
       php81-xmlreader \
       php81-zip \
       php81-opcache \
       less

RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /etc/php81/conf.d/opcache-recommended.ini

VOLUME /var/www/wp-content

WORKDIR /usr/src

RUN set -x \
    && mkdir /usr/src/wordpress \
    && chown -R $UID:$GID /usr/src/wordpress \
    && sed -i s/';cgi.fix_pathinfo=1/cgi.fix_pathinfo=0'/g /etc/php81/php.ini \
    && sed -i s/'expose_php = On/expose_php = Off'/g /etc/php81/php.ini \
    && ln -s /sbin/php-fpm81 /sbin/php-fpm

COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php81/php-fpm.d/zzz_custom_fpm_pool.conf
COPY config/php.ini /etc/php81/conf.d/zzz_custom_php.ini
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/nginx_includes/* /etc/nginx/includes/
COPY wp-config.php /usr/src/wordpress
COPY rootfs.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/rootfs.sh
COPY --from=download /tmp/wp /usr/local/bin/wp
COPY --from=download /tmp/wp-secrets.php /usr/src/wordpress/wp-secrets.php

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

RUN set -x \
    && chmod +x /usr/local/bin/wp \
    && chown $UID:$GID /usr/local/bin/wp \
    && wp core download --path=/usr/src/wordpress --version="${WP_VERSION}" --skip-content --locale="${WP_LOCALE}" \
    && chown -hR $UID:$GID /usr/src/wordpress

WORKDIR /var/www/wp-content

EXPOSE 8080

USER $UID

STOPSIGNAL SIGQUIT

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
