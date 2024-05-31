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
# see configuration : https://hub.docker.com/_/php
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

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
# dev extensions
# To start xdebug for a interactive cli use this :
# XDEBUG_MODE=debug XDEBUG_SESSION=1 XDEBUG_CONFIG="client_host=172.17.0.1 client_port=9003" PHP_IDE_CONFIG="serverName=myrepl" php /app/hello.php
# A phpstorm server with the appropriate name is also needed ( Config : PHP > Servers )
RUN install-php-extensions xdebug

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

# Add psysh - https://github.com/bobthecow/psysh
RUN curl -L -o /tmp/psysh.tar.gz https://github.com/bobthecow/psysh/releases/download/v0.12.0/psysh-v0.12.0.tar.gz \
    && tar -xvf /tmp/psysh.tar.gz -C /usr/local/bin/ \
    && chmod 500 /usr/local/bin/psysh \
    && chown climber /usr/local/bin/psysh \
    && psysh --version

# Add symfony cli
RUN curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.alpine.sh' | bash \
    && apk --no-cache add symfony-cli \
    && symfony local:check:requirements

USER climber
# configure git (needed for symnfony cli)
ARG GIT_EMAIL
ARG GIT_USERNAME
RUN git config --global user.email "${GIT_EMAIL}" \
    && git config --global user.name "${GIT_USERNAME}"

# Add php-cs-fixer
# @deprecated, better include it in the composer.json
ARG PHP_CS_FIXER_VERSION
ADD --chown=climber:climber \
    --chmod=744 \
    https://github.com/PHP-CS-Fixer/PHP-CS-Fixer/releases/download/v${PHP_CS_FIXER_VERSION}/php-cs-fixer.phar \
    /usr/local/bin/php-cs-fixer

# Add composer binaries to path
RUN ["fish", "-c fish_add_path /app/vendor/bin"]

# switch back to www-data user ?

