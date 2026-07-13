FROM node:20-alpine AS assets
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --ignore-platform-reqs

FROM php:8.3-apache
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip git curl libzip-dev \
    && docker-php-ext-install pdo pdo_mysql mysqli bcmath \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i 's|/var/www/html|/var/www/html/public|g' /etc/apache2/sites-available/000-default.conf \
    && echo '<Directory /var/www/html/public>\n    AllowOverride All\n</Directory>' >> /etc/apache2/apache2.conf

WORKDIR /var/www/html
COPY . .
COPY --from=vendor /app/vendor ./vendor
COPY --from=assets /app/public/build ./public/build
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN composer dump-autoload --optimize \
    && chown -R www-data:www-data /var/www/html

EXPOSE 10000

CMD sh -c "sed -i \"s/Listen 80/Listen \${PORT:-10000}/\" /etc/apache2/ports.conf \
    && sed -i \"s/:80>/:\${PORT:-10000}>/\" /etc/apache2/sites-available/000-default.conf \
    && php artisan migrate --force \
    && apache2-foreground"