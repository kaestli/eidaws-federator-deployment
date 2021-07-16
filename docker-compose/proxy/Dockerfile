# Dockerizing eidaws-federator endpoint caching proxy
#
# Build Container:
# docker build -t eidaws-endpoint-proxy:1.1 .
#
# Run Container:
# docker run [-d] [--rm] [--name eidaws-endpoint-proxy] \
#   -p 8090:8090 eidaws-endpoint-proxy:1.1
#
# Modify running container:
# docker exec -it eidaws-endpoint-proxy /bin/bash

# Base image
FROM docker.io/phusion/baseimage:focal-1.0.0

ARG DIR_CONTAINERFILE=proxy

# Add label metadata
LABEL maintainer="Daniel Armbruster"
LABEL email="daniel.armbruster@sed.ethz.ch"

CMD ["/sbin/my_init"]

# System dependencies
RUN export DEBIAN_FRONTEND=noninteractive && \
  apt-get update && apt-get install -y python3-dev \
                                       python3-pip \
                                       python3-venv \
                                       nginx \
                                       nginx-extras

# Configure nginx
COPY $DIR_CONTAINERFILE/conf.d /etc/nginx/conf.d
COPY $DIR_CONTAINERFILE/nginx.conf /etc/nginx

# Add the nginx service
RUN mkdir /etc/service/nginx && \
	echo "#!/bin/sh\nexec nginx 2>&1" > /etc/service/nginx/run && \
	chmod +x /etc/service/nginx/run

# Install backend services
RUN mkdir -p /var/www/eidaws-endpoint-proxy /run/eidaws-endpoint-proxy \
  /var/log/eidaws && chown www-data:www-data /run/eidaws-endpoint-proxy
COPY $DIR_CONTAINERFILE/../eidaws/eidaws.utils /usr/local/src/eidaws/eidaws.utils/
COPY $DIR_CONTAINERFILE/../eidaws/eidaws.endpoint_proxy \
  /usr/local/src/eidaws/eidaws.endpoint_proxy/

# Setup virtualenv and install services
RUN python3.8 -m venv /var/www/eidaws-endpoint-proxy/venv && \
  /bin/bash -c "source /var/www/eidaws-endpoint-proxy/venv/bin/activate && \
  pip install --upgrade pip && \
  pip install -e /usr/local/src/eidaws/eidaws.utils && \
  pip install -e /usr/local/src/eidaws/eidaws.endpoint_proxy && deactivate"

# Backend service configuration files
COPY $DIR_CONTAINERFILE/*logging.conf /etc/eidaws/
COPY $DIR_CONTAINERFILE/eidaws-endpoint-proxy.syslog-ng.conf \
  /etc/syslog-ng/conf.d/eidaws-endpoint-proxy.conf
COPY $DIR_CONTAINERFILE/logrotate/* /etc/logrotate.d/
RUN chmod 644 /etc/logrotate.d/*

# Add proxy backend services with installation script
COPY $DIR_CONTAINERFILE/eidaws_proxy_config.yml.template \
  $DIR_CONTAINERFILE/install_backend.py \
  $DIR_CONTAINERFILE/eidaws-endpoint.json /tmp/
RUN chmod +x /tmp/install_backend.py && \
  cat /tmp/eidaws-endpoint.json | ./tmp/install_backend.py

# Expose HTTP default port
EXPOSE 8090

# Cleanup (baseimage recommended)
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
