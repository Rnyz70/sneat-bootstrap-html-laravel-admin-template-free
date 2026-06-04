# Stage 1: Composer dependencies
FROM php:8.2-cli AS composer

RUN apt-get update && apt-get install -y \
    unzip \
    zip \
    libzip-dev \
    && docker-php-ext-install zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

COPY composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-scripts

COPY . .

# Stage 2: Frontend build
FROM node:20 AS node

WORKDIR /app

COPY package*.json ./

RUN npm install --legacy-peer-deps

COPY . .

RUN npm run build

# Stage 3: Production image
FROM php:8.2-fpm

RUN apt-get update && apt-get install -y \
    libzip-dev \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    && docker-php-ext-install \
        pdo \
        pdo_mysql \
        zip \
        dom \
        xml \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www

COPY --from=composer /app /var/www

COPY --from=node /app/public/build /var/www/public/build

RUN chown -R www-data:www-data storage bootstrap/cache

RUN groupadd -g 1000 laravel && \
    useradd -u 1000 -g laravel -m laravel

RUN chown -R laravel:laravel /var/www

USER laravel

CMD ["php-fpm"]
