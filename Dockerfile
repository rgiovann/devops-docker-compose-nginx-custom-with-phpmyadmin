FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

# Instala nginx, php-fpm, mysql driver, unzip e curl
RUN apt-get update && \
    apt-get install -y nginx php8.2-fpm php8.2-mysql unzip curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Cria a pasta e baixa o PhpMyAdmin
RUN mkdir -p /var/www/html && \
    curl -L https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip -o /tmp/phpmyadmin.zip && \
    unzip /tmp/phpmyadmin.zip -d /tmp/ && \
    mv /tmp/phpMyAdmin-5.2.1-all-languages /var/www/html/phpmyadmin && \
    rm -rf /tmp/*

# Copia o arquivo de configuração do phpMyAdmin
COPY config.inc.php /var/www/html/phpmyadmin/config.inc.php

# Ajusta permissões para evitar 403
RUN chown -R www-data:www-data /var/www/html && chmod -R 755 /var/www/html

# Expõe as portas necessárias
EXPOSE 80

# Inicializa php-fpm e nginx
CMD php-fpm8.2 -D && nginx -g "daemon off;"
