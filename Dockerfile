# Updated 9/6/2021
FROM ubuntu:18.04
LABEL maintainer="Peter Thomas <peter@peterkthomas.com>"

# Build variables
ARG NGINX_VERSION=1.21.2
ARG SBIN_PATH=/usr/bin/nginx
ARG CONF_PATH=/etc/nginx/nginx.conf
ARG LOG_DIR=/var/log/nginx
ARG PID=/var/run/nginx.pid
ARG APP_URL=https://github.com/spreedly/sample-payment-frame.git
ARG APP_DIR=/app

# Runs as root, get packages needed:
RUN apt-get update \
	&& apt-get -y upgrade \
	&& apt-get -y install --no-install-recommends \
		openssl \
		curl \
		build-essential \
		libpcre3 \
		libpcre3-dev \
		zlib1g \
		zlib1g-dev \
		libssl-dev \
		ca-certificates \
		git \
	&& rm -rf /var/lib/apt/lists/*

# Generate a self-signed SSL certificate and store it in /etc/ssl.
# Also using DHparams to protect against logjam attacks on a 2048 bit key.
# I decided to use this value due to the huge increase in CPU usage at 4096.
RUN openssl req -newkey rsa:2048 -new -nodes -x509 -days 365 \
	-subj  "/C=US/ST=CT/O=peterthomas/CN=localhost" \
	-keyout /etc/ssl/self.key -out /etc/ssl/self.crt \
	&& openssl dhparam -out /etc/ssl/dhparam.pem 2048

# Using mainline nginx for bug fixes, stable can get outdated
# additionally, I feel the use of a version should be a business decision based on
# risk and security. Also I am configuring minimum amounts of modules for memory usage/security.
WORKDIR /root
RUN curl http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz && tar -xvzf nginx.tar.gz

RUN cd nginx-${NGINX_VERSION} \
	&& ./configure --sbin-path=${SBIN_PATH} --conf-path=${CONF_PATH} \
		--error-log-path=${LOG_DIR}/error.log --http-log-path=${LOG_DIR}/access.log \
		--pid-path=${PID} --with-http_ssl_module --with-http_v2_module \
		--without-http_fastcgi_module --without-http_gzip_module \
		--without-stream_upstream_zone_module --without-http_ssi_module \
		--without-stream_upstream_random_module --without-stream_upstream_least_conn_module \
		--without-stream_upstream_hash_module --without-stream_set_module \
		--without-stream_return_module --without-stream_split_clients_module \
		--without-stream_map_module --without-stream_geo_module \
		--without-stream_access_module --without-stream_limit_conn_module \
		--without-mail_smtp_module --without-mail_imap_module \
		--without-mail_pop3_module --without-http_upstream_zone_module \
		--without-http_upstream_keepalive_module --without-http_upstream_random_module \
		--without-http_upstream_least_conn_module --without-http_upstream_ip_hash_module \
		--without-http_upstream_hash_module --without-http_browser_module \
		--without-http_empty_gif_module --without-http_grpc_module \
		--without-http_scgi_module --without-http_uwsgi_module \
		--without-http_fastcgi_module --without-http_proxy_module \
		--without-http_split_clients_module --without-http_map_module \
		--without-http_geo_module  --without-http_autoindex_module \
		--without-http_mirror_module --without-http_auth_basic_module \
	&& make && make install \
	&& rm -rf /root/nginx-${NGINX_VERSION} /root/nginx.tar.gz

# Copies my NginX configuration for this application.
COPY nginx.conf /etc/nginx/nginx.conf

# Forward request logs to Docker log collector.
# Just creating a symbolic link to stdout and stderr.
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# Clone the project from git to /app.
# Only index.html and the css folder are needed. Nothing else seems necessary.
# This would really be linked to an S3 bucket or some other provider.
RUN mkdir ${APP_DIR} && cd ${APP_DIR} && git clone ${APP_URL} .

# Remove unneeded packages
RUN apt-get remove --purge -y curl git

EXPOSE 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]