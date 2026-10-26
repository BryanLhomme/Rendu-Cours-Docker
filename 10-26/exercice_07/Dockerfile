FROM mysql

ENV MYSQL_ROOT_PASSWORD=root
ENV MYSQL_DATABASE=kennelDB

COPY init.sql /docker-entrypoint-initdb.d/
