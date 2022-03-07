# Dockerizing eidaws-stationlite
#
# Build Container:
# docker build -t eidaws-stationlite:TAG .
#
# Run Container:
# docker run [-d] [--rm] [--name eidaws-stationlite] -p 8089:8089 \
#   eidaws-stationlite:TAG
#
# Modify running container:
# docker exec -it eidaws-stationlite /bin/bash

# Base image
FROM docker.io/phusion/baseimage:focal-1.0.0

ARG DIR_CONTAINERFILE=stationlite

ENV EIDAWS_STATIONLITE_SETTINGS=/etc/eidaws/eidaws_stationlite_server_config.yml
ENV FLASK_APP=/usr/local/src/eidaws/eidaws.stationlite/eidaws/stationlite/server/

# Add label metadata
LABEL maintainer="Daniel Armbruster"
LABEL email="daniel.armbruster@sed.ethz.ch"

CMD ["/sbin/my_init"]

# System dependencies
RUN export DEBIAN_FRONTEND=noninteractive && \
  apt-get update && apt-get install -y python3-dev \
                                       python3-venv \
                                       python3-pip \
                                       python3-virtualenv \
                                       build-essential \
                                       libpq-dev \
                                       apache2 \
                                       libapache2-mod-wsgi-py3

# Install backend services
RUN mkdir -p /var/www/eidaws-stationlite /var/log/eidaws
COPY $DIR_CONTAINERFILE/../eidaws/eidaws.utils /usr/local/src/eidaws/eidaws.utils/
COPY $DIR_CONTAINERFILE/../eidaws/eidaws.stationlite \
  /usr/local/src/eidaws/eidaws.stationlite/

# Setup virtualenv and install eidaws.stationlite distribution
RUN virtualenv /var/www/eidaws-stationlite/venv && \
  /bin/bash -c "source /var/www/eidaws-stationlite/venv/bin/activate && \
  pip install --upgrade pip && \
  pip install numpy==1.21.5 && \
  pip install -e /usr/local/src/eidaws/eidaws.utils && \
  pip install -e /usr/local/src/eidaws/eidaws.stationlite[postgres] && deactivate"

# Copy eidaws-stationlite(-harvest) configuration files
COPY $DIR_CONTAINERFILE/*.yml $DIR_CONTAINERFILE/*logging.conf \
  $DIR_CONTAINERFILE/env /etc/eidaws/
COPY $DIR_CONTAINERFILE/eidaws-stationlite.syslog-ng.conf \
  /etc/syslog-ng/conf.d/eidaws-stationlite.conf
COPY $DIR_CONTAINERFILE/logrotate/* /etc/logrotate.d/
RUN chmod 644 /etc/logrotate.d/*
COPY $DIR_CONTAINERFILE/apache.syslog-ng.conf /etc/syslog-ng/conf.d/apache.conf

# Copy Apache configuration configuration
COPY $DIR_CONTAINERFILE/httpd.conf /etc/apache2/sites-available/

# Copy the WSGI configuration scripts
COPY $DIR_CONTAINERFILE/*.wsgi /var/www/eidaws-stationlite/

# Give read permissions
RUN chmod +r /etc/eidaws/* \
  /var/www/eidaws-stationlite/*.wsgi

# Enable the supplied WSGI modules
RUN a2dissite 000-default.conf && a2ensite httpd.conf

# Add the apache2 service
RUN mkdir /etc/service/apache2 && \
	echo "#!/bin/sh\nexec apachectl -D FOREGROUND" > /etc/service/apache2/run && \
	chmod +x /etc/service/apache2/run

# Add the harvesting cronjob (once per day)
RUN sed -e 's/^/export /' -i /etc/eidaws/env
RUN echo "0 1 * * * root . /etc/eidaws/env; /var/www/eidaws-stationlite/venv/bin/eida-stationlite-harvest" >> /etc/crontab

# Expose HTTP default port
EXPOSE 8089

# Cleanup (baseimage recommended)
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
