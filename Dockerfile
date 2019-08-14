FROM alpine:3.10
LABEL Maintainer="Carlos R <nidr0x@gmail.com>" \
      Description="WP container in Debian Linux with nginx 1.16.0 and latest stable PHP-FPM 7x"

ENV WP_VERSION 5.1.1

RUN set -x \
    && addgroup -g 82 -S www-data \
    && adduser -u 82 -D -S -G www-data www-data

RUN apk --no-cache add php7 php7-fpm php7-mysqli php7-json php7-openssl php7-curl \
    php7-simplexml php7-ctype php7-mbstring php7-gd nginx=1.16.0-r2 supervisor curl \
    php7-zlib php7-xml php7-phar php7-intl php7-dom php7-xmlreader \
    libpng libjpeg-turbo bash \
    && rm -rf /var/www/localhost

VOLUME /var/www/wp-content
WORKDIR /var/www/wp-content
RUN chown -R www-data:www-data /var/www

WORKDIR /usr/src
RUN mkdir -p /usr/src/wordpress \
    && curl -sfo /usr/src/wordpress.tar.gz  -L https://wordpress.org/wordpress-${WP_VERSION}.tar.gz  \
    && tar -xzf /usr/src/wordpress.tar.gz \
    && rm -rf /usr/src/wordpress.tar.gz \
    && rm -rf /usr/src/wp-content \
    && ln -s /var/www/wp-content/ /usr/src/wordpress/wp-content \
    && ln -s /var/www/images/ /usr/src/wordpress/images \
    && chown -R www-data:www-data /usr/src/wordpress \
    && sed -i s/'user = nobody'/'user = www-data'/g /etc/php7/php-fpm.d/www.conf \
    && sed -i s/'group = nobodoy'/'group = www-data'/g /etc/php7/php-fpm.d/www.conf

COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/fpm-pool.conf
COPY config/php.ini /etc/php7/conf.d/php.ini
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/wp_cron /etc/cron.d/wp_cron
COPY wp-config.php /usr/src/wordpress
COPY wp-secrets.php /usr/src/wordpress

RUN rm -rf /tmp/* \
    && chmod 0755 /etc/cron.d/wp_cron \
    && chown www-data:www-data /usr/src/wordpress/wp-config.php \
    && chmod 660 /usr/src/wordpress/wp-config.php \
    && chown www-data:www-data /usr/src/wordpress/wp-secrets.php \
    && chmod 660 /usr/src/wordpress/wp-secrets.php \
    && curl -sfo /usr/local/bin/wp -L https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
