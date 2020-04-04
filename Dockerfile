FROM alpine:3.11 AS download
LABEL Maintainer="Carlos R <nidr0x@gmail.com>" \
      Description="WP container in Alpine Linux with nginx 1.16.0 and latest stable PHP-FPM 7x"

ENV WP_VERSION 5.4

RUN apk --no-cache add curl \
    && curl -sfo /root/wordpress.tar.gz -L https://wordpress.org/wordpress-${WP_VERSION}.tar.gz

FROM alpine:3.11

RUN set -x \
    && addgroup -g 82 -S www-data \
    && adduser -u 82 -D -S -G www-data www-data \
    && apk --no-cache add php7 php7-fpm php7-mysqli php7-json php7-openssl php7-curl \
       php7-simplexml php7-ctype php7-mbstring php7-gd php7-exif nginx~=1.16 supervisor curl \
       php7-zlib php7-xml php7-phar php7-intl php7-dom php7-xmlreader php7-zip php7-opcache less \
       bash \
    && rm -rf /var/www/localhost

RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /etc/php7/conf.d/opcache-recommended.ini

VOLUME /var/www/wp-content

RUN set -x \ 
    && chown -R www-data:www-data /var/www \
    && mkdir -p /usr/src/wordpress

WORKDIR /usr/src

COPY --from=download /root/wordpress.tar.gz /usr/src/wordpress.tar.gz

RUN set -x \
    && tar -xzf /usr/src/wordpress.tar.gz \
    && rm -rf /usr/src/wordpress.tar.gz \
    && rm -rf /usr/src/wordpress/wp-content \
    && chown -R www-data:www-data /usr/src/wordpress \
    && sed -i s/';cgi.fix_pathinfo=1/cgi.fix_pathinfo=0'/g /etc/php7/php.ini \
    && sed -i s/'expose_php = On/expose_php = Off'/g /etc/php7/php.ini \
    && sed -i s/'user = nobody'/'user = www-data'/g /etc/php7/php-fpm.d/www.conf \
    && sed -i s/'group = nobody'/'group = www-data'/g /etc/php7/php-fpm.d/www.conf \
    && sed -i "s/nginx:x:100:101:nginx:\/var\/lib\/nginx:\/sbin\/nologin/nginx:x:100:101:nginx:\/usr:\/bin\/bash/g" /etc/passwd \
    && ln -s /sbin/php-fpm7 /sbin/php-fpm

COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/zzz_custom_fpm_pool.conf
COPY config/php.ini /etc/php7/conf.d/zzz_custom_php.ini
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/nginx_includes/* /etc/nginx/includes/
COPY wp-config.php /usr/src/wordpress
COPY wp-secrets.php /usr/src/wordpress
COPY rootfs/* /usr/src/wordpress/
COPY config/cron.conf /etc/crontabs/www-data

RUN set -x \
    && rm -rf /tmp/* \
    && chown www-data:www-data /usr/src/wordpress/wp-config.php \
    && chmod 660 /usr/src/wordpress/wp-config.php \
    && chown www-data:www-data /usr/src/wordpress/wp-secrets.php \
    && chmod 660 /usr/src/wordpress/wp-secrets.php \
    && chmod 600 /etc/crontabs/www-data \
    && curl -sfo /usr/local/bin/wp -L https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp \
    && chown nginx:nginx /usr/local/bin/wp \
    && wp core verify-checksums --path=/usr/src/wordpress

WORKDIR /var/www/wp-content

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

EXPOSE 80

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
