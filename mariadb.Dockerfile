FROM mariadb:11.8.10

COPY config/my.cnf /etc/mysql/conf.d/zzz_my.cnf
