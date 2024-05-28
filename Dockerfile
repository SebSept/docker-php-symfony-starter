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

FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION} AS php
EXPOSE 9000/tcp

# config system
# git is required for symfony cli
RUN apk update --no-cache \
    && apk add fish bash git

# Add php extension installer
# available extensions : https://github.com/mlocati/docker-php-extension-installer#supported-php-extensions
ADD --chmod=700 \
    https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions \
    /usr/local/bin/

# runtime extensions - https://symfony.com/doc/current/setup.html#technical-requirements
# already bundled : Ctype , iconv, PCRE, Session, Tokenizer, simplexml
# json, mbstring (bundled)
RUN install-php-extensions intl pdo_pgsql opcache apcu


# since we use php-fpm, we may use www-data user @todo
RUN adduser -D -s /usr/bin/fish -h /home/climber -u 1000 climber

# Add composer
# We may also use `install-php-extensions @composer` (not tested)
# or get the binary from the composer docker image
ARG COMPOSER_VERSION
ADD --chown=climber:climber \
    --chmod=744 \
    https://github.com/composer/composer/releases/download/${COMPOSER_VERSION}/composer.phar \
    /usr/local/bin/composer
RUN composer --version

# Create app directory & vendor/bin (needed ?)
WORKDIR /app
RUN chown climber /app && mkdir -p /app/vendor/bin/

# Add symfony cli
# will probably be removed to production image
RUN curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.alpine.sh' | bash \
    && apk --no-cache add symfony-cli \
    && symfony local:check:requirements

USER climber
# configure git (needed for symnfony cli)
ARG GIT_EMAIL
ARG GIT_USERNAME
RUN git config --global user.email "${GIT_EMAIL}" \
    && git config --global user.name "${GIT_USERNAME}"

# Add composer binaries to path
RUN ["fish", "-c fish_add_path /app/vendor/bin"]

# switch back to www-data user ?

