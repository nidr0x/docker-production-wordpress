FROM alpine:3.18 AS download

ENV WPCLI_DOWNLOAD_SHA256 8503cd579480d0cb237b4bef35e0c3da11c2ab872a1bc8f26d2da0ca0729b6a7

RUN apk add --no-cache \
    curl \ 
    coreutils

RUN set -x \
    && curl -sfo /tmp/wp -L https://github.com/wp-cli/wp-cli/releases/download/v2.8.1/wp-cli-2.8.1.phar \
    && echo "$WPCLI_DOWNLOAD_SHA256 /tmp/wp" | sha256sum -c -

RUN set -x \
    && curl -f https://api.wordpress.org/secret-key/1.1/salt/ >> /tmp/wp-secrets.php

FROM alpine:3.18

LABEL Maintainer="Carlos R <nidr0x@gmail.com>" \
      Description="Slim WordPress image using Alpine Linux"

ENV WP_VERSION 6.3.1
ENV WP_LOCALE en_US

ARG UID=82
ARG GID=82

RUN adduser -u $UID -D -S -G www-data www-data \
    && apk add --no-cache \
       php82 \
       php82-fpm \
       php82-mysqli \
       php82-json \
       php82-openssl \
       php82-curl \
       php82-simplexml \
       php82-ctype \
       php82-mbstring \
       php82-gd \
       php82-exif \
       nginx \
       supervisor \
       php82-zlib \
       php82-xml \
       php82-phar \
       php82-intl \
       php82-dom \
       php82-xmlreader \
       php82-zip \
       php82-opcache \
       php82-fileinfo \
       php82-iconv \
       less

RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /etc/php82/conf.d/opcache-recommended.ini

VOLUME /var/www/wp-content

WORKDIR /usr/src

RUN set -x \
    && mkdir /usr/src/wordpress \
    && chown -R $UID:$GID /usr/src/wordpress \
    && sed -i s/';cgi.fix_pathinfo=1/cgi.fix_pathinfo=0'/g /etc/php82/php.ini \
    && sed -i s/'expose_php = On/expose_php = Off'/g /etc/php82/php.ini \
    && ln -s /usr/bin/php82 /usr/bin/php \
    && ln -s /usr/sbin/php-fpm82 /usr/sbin/php-fpm

COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php82/php-fpm.d/zzz_custom_fpm_pool.conf
COPY config/php.ini /etc/php82/conf.d/zzz_custom_php.ini
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
