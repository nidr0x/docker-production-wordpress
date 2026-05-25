FROM mariadb:11.0

COPY config/my.cnf /etc/mysql/conf.d/zzz_my.cnf

USER mysql
