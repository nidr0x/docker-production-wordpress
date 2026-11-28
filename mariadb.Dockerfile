FROM mariadb:13.1.2

COPY config/my.cnf /etc/mysql/conf.d/zzz_my.cnf
