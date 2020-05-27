#
# Base install step (done first for caching purposes).
#
FROM ubuntu:focal as base

ENV TZ="UTC"

# Run base build process
COPY ./util/docker/web/ /bd_build

RUN chmod a+x /bd_build/*.sh \
    && /bd_build/prepare.sh \
    && /bd_build/add_user.sh \
    && /bd_build/setup.sh \
    && /bd_build/cleanup.sh \
    && rm -rf /bd_build

# Install SFTPgo
COPY --from=azuracast/azuracast_golang_deps:latest /usr/local/bin/sftpgo /usr/local/bin/sftpgo

# Install Dockerize
COPY --from=azuracast/azuracast_golang_deps:latest /usr/local/bin/dockerize /usr/local/bin/dockerize

#
# START Operations as `azuracast` user
#
USER azuracast

WORKDIR /var/azuracast/www

COPY --chown=azuracast:azuracast ./composer.json ./composer.lock ./
RUN composer install \
    --no-dev \
    --no-ansi \
    --no-autoloader \
    --no-interaction \
    --no-scripts

COPY --chown=azuracast:azuracast . .

RUN composer dump-autoload --optimize --classmap-authoritative \
    && touch /var/azuracast/.docker

VOLUME ["/var/azuracast/www", "/var/azuracast/backups", "/etc/letsencrypt", "/var/azuracast/sftpgo/persist"]

#
# END Operations as `azuracast` user
#
USER root

EXPOSE 80 443 2022

# Nginx Proxy environment variables.
ENV VIRTUAL_HOST="azuracast.local" \
    HTTPS_METHOD="noredirect"

# Sensible default environment variables.
ENV APPLICATION_ENV="production" \
    ENABLE_ADVANCED_FEATURES="false" \
    MYSQL_HOST="mariadb" \
    MYSQL_PORT=3306 \
    MYSQL_USER="azuracast" \
    MYSQL_PASSWORD="azur4c457" \
    MYSQL_DATABASE="azuracast" \
    PREFER_RELEASE_BUILDS="false" \
    COMPOSER_PLUGIN_MODE="false" \
    ADDITIONAL_MEDIA_SYNC_WORKER_COUNT=0

# Entrypoint and default command
ENTRYPOINT ["dockerize",\
    "-wait","tcp://mariadb:3306",\
    "-wait","tcp://influxdb:8086",\
    "-wait","tcp://redis:6379",\
    "-timeout","40s"]
CMD ["/usr/local/bin/my_init"]
