FROM public.ecr.aws/docker/library/alpine:3.19 AS download

ENV WPCLI_DOWNLOAD_SHA256 af6b7ccc21ed0907cb504db5a059f0e120117905a6017bfdd4375cee3c93d864

RUN apk add --no-cache \
    curl \ 
    coreutils

RUN set -x \
    && curl -sfo /tmp/wp -L https://github.com/wp-cli/wp-cli/releases/download/v2.9.0/wp-cli-2.9.0.phar \
    && echo "$WPCLI_DOWNLOAD_SHA256 /tmp/wp" | sha256sum -c -

RUN set -x \
    && curl -f https://api.wordpress.org/secret-key/1.1/salt/ >> /tmp/wp-secrets.php

FROM public.ecr.aws/docker/library/alpine:3.19

LABEL Maintainer="Carlos R <nidr0x@gmail.com>" \
      Description="Slim WordPress image using Alpine Linux"

ENV WP_VERSION 6.4.3
ENV WP_LOCALE en_US

ARG UID=82
ARG GID=82

RUN adduser -u $UID -D -S -G www-data www-data \
    && apk add --no-cache \
       php83 \
       php83-fpm \
       php83-mysqli \
       php83-json \
       php83-openssl \
       php83-curl \
       php83-simplexml \
       php83-ctype \
       php83-mbstring \
       php83-gd \
       php83-exif \
       nginx \
       supervisor \
       php83-zlib \
       php83-xml \
       php83-phar \
       php83-intl \
       php83-dom \
       php83-xmlreader \
       php83-zip \
       php83-opcache \
       php83-fileinfo \
       php83-iconv \
       less

RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /etc/php83/conf.d/opcache-recommended.ini

VOLUME /var/www/wp-content

WORKDIR /usr/src

RUN set -x \
    && mkdir /usr/src/wordpress \
    && chown -R $UID:$GID /usr/src/wordpress \
    && sed -i s/';cgi.fix_pathinfo=1/cgi.fix_pathinfo=0'/g /etc/php83/php.ini \
    && sed -i s/'expose_php = On/expose_php = Off'/g /etc/php83/php.ini \
    && ln -s /usr/bin/php83 /usr/bin/php \
    && ln -s /usr/sbin/php-fpm83 /usr/sbin/php-fpm

COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php83/php-fpm.d/zzz_custom_fpm_pool.conf
COPY config/php.ini /etc/php83/conf.d/zzz_custom_php.ini
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
