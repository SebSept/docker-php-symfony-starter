# syntax=docker/dockerfile:labs
# https://github.com/composer/composer/releases/
ARG COMPOSER_VERSION=2.7.6
# voir https://hub.docker.com/_/php/tags?page=&page_size=&ordering=&name=fpm-a
ARG PHP_VERSION=8.3.7
ARG ALPINE_VERSION=3.20
# https://github.com/PHP-CS-Fixer/PHP-CS-Fixer/releases
ARG PHP_CS_FIXER_VERSION=3.57.2
ARG GIT_EMAIL="seb@local.fr"
ARG GIT_USERNAME="seb"

# Do not expose the port to the host.
# https://hub.docker.com/_/php
# WARNING: the FastCGI protocol is inherently trusting, and thus extremely insecure to expose outside of a private container network -- unless you know exactly what you are doing (and are willing to accept the extreme risk), do not use Docker's --publish (-p) flag with this image variant.

FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION} AS php-builder

# Use php development configuration
# see configuration : https://hub.docker.com/_/php
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
# 256 MB de mémoire
RUN sed -i 's/memory_limit = 128M/memory_limit = 256M/' "$PHP_INI_DIR/php.ini"
# config system
# git is required for symfony cli
# supervisor is required for worker (then messenger)
#RUN apk update --no-cache \
#    && apk add fish bash git supervisor
#RUN apk update --no-cache \
#    && apk add bash git

# Add php extension installer
# available extensions : https://github.com/mlocati/docker-php-extension-installer#supported-php-extensions
ADD --chmod=755 \
    https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions \
    /usr/local/bin/

# runtime extensions - https://symfony.com/doc/current/setup.html#technical-requirements
# already bundled : Ctype , iconv, PCRE, Session, Tokenizer, simplexml
# json, mbstring (bundled)
# opcache, apcu required for internal php/symfony performance
# imagick for image manipulation, @see https://github.com/liip/LiipImagineBundle
RUN install-php-extensions intl pdo_pgsql
RUN install-php-extensions opcache apcu
RUN install-php-extensions gmagick

# dev extensions
# To start xdebug for a interactive cli use this :
# XDEBUG_MODE=debug XDEBUG_SESSION=1 XDEBUG_CONFIG="client_host=172.17.0.1 client_port=9003" PHP_IDE_CONFIG="serverName=myrepl" php /app/hello.php
# A phpstorm server with the appropriate name is also needed ( Config : PHP > Servers )

# Add composer
# We may also use `install-php-extensions @composer` (not tested)
#RUN install-php-extensions @${COMPOSER_VERSION}
# or get the binary from the composer docker image
# maybe getting the binary from the composer image is better for docker scout scanning ...
ARG COMPOSER_VERSION
ADD --chown=www-data:www-data --chmod=755 https://github.com/composer/composer/releases/download/${COMPOSER_VERSION}/composer.phar \
    /usr/local/bin/composer

# ------------------

FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION} AS final
COPY --from=php-builder /usr/local/bin /usr/local/bin
COPY --from=php-builder /usr/local/etc /usr/local/etc
COPY --from=php-builder /usr/local/lib /usr/local/lib
COPY --from=php-builder /usr/lib /usr/lib

EXPOSE 9000/tcp

# Create app directory & vendor/bin (needed ?)
RUN mkdir -p /app/var/
RUN chown www-data:www-data /app -R

RUN apk update --no-cache \
    && apk add fish git supervisor icu icu-data-full \
    && apk cache clean

USER www-data
WORKDIR /app

# Add composer binaries to path
RUN mkdir /app/vendor/bin -p
RUN ["fish", "-c fish_add_path /app/vendor/bin"]

# configure git (needed for symnfony cli)
ARG GIT_EMAIL
ARG GIT_USERNAME
RUN git config --global user.email "${GIT_EMAIL}" \
    && git config --global user.name "${GIT_USERNAME}"
