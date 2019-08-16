FROM nginx:alpine AS builder

# nginx:alpine contains NGINX_VERSION environment variable, like so:
# ENV NGINX_VERSION 1.15.0

ENV ngx_devel_kit_version 0.3.1
ENV lua_nginx_version 0.10.15
ENV sticky_module_version 08a395c66e42
ENV sticky_module_version_internal 08a395c66e42
ENV nginx_http_shibboleth_version 2.0.1
ENV headers_more_version 0.33

# For latest build deps, see https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine/Dockerfile
RUN apk add --no-cache --virtual .build-deps \
  gcc \
  libc-dev \
  make \
  openssl-dev \
  pcre-dev \
  zlib-dev \
  linux-headers \
  curl \
  gnupg \
  libxslt-dev \
  gd-dev \
  luajit \
  luajit-dev \
  geoip-dev

# Download sources
RUN curl -L -o /tmp/nginx.tar.gz "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" && \
  curl -L -o /tmp/ngx_devel_kit-${ngx_devel_kit_version}.tar.gz https://github.com/simpl/ngx_devel_kit/archive/v${ngx_devel_kit_version}.tar.gz && \
  curl -L -o /tmp/lua-nginx-module-${lua_nginx_version}.tar.gz https://github.com/openresty/lua-nginx-module/archive/v${lua_nginx_version}.tar.gz && \
  curl -L -o /tmp/nginx-goodies-nginx-sticky-module-ng-${sticky_module_version}.tar.gz https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng/get/${sticky_module_version}.tar.gz && \
  curl -L -o /tmp/nginx-http-shibboleth-${nginx_http_shibboleth_version}.tar.gz https://github.com/nginx-shib/nginx-http-shibboleth/archive/v${nginx_http_shibboleth_version}.tar.gz && \
  curl -L -o /tmp/headers-more-nginx-module-${headers_more_version}.tar.gz https://github.com/openresty/headers-more-nginx-module/archive/v${headers_more_version}.tar.gz

# Last Commits for master branch on Feb 28, 2015
COPY nginx_ajp_module-master.tar.gz /tmp/nginx_ajp_module-master.tar.gz
# Latest commit 1a92c67  on 19 Jul 2017
COPY ngx_upstream_jdomain-master.tar.gz  /tmp/ngx_upstream_jdomain-master.tar.gz
COPY core.patch /tmp/core.patch
COPY shibboleth.patch  /tmp/shibboleth.patch
COPY sticky.patch /tmp/sticky.patch

ENV LUAJIT_INC /usr/include/luajit-2.1
ENV LUAJIT_LIB /usr/lib

# Reuse same cli arguments as the nginx:alpine image used to build
RUN mkdir -p /usr/src
WORKDIR /usr/src
RUN tar -zxf /tmp/nginx.tar.gz && \
  tar -zxf /tmp/ngx_devel_kit-${ngx_devel_kit_version}.tar.gz && \
  tar -zxf /tmp/lua-nginx-module-${lua_nginx_version}.tar.gz && \
  tar -zxf /tmp/nginx-goodies-nginx-sticky-module-ng-${sticky_module_version}.tar.gz && \
  tar -zxf /tmp/nginx-http-shibboleth-${nginx_http_shibboleth_version}.tar.gz && \
  tar -zxf /tmp/headers-more-nginx-module-${headers_more_version}.tar.gz && \
  tar -zxf /tmp/nginx_ajp_module-master.tar.gz && \
  tar -zxf /tmp/ngx_upstream_jdomain-master.tar.gz

RUN patch -p 1 < /tmp/shibboleth.patch
RUN patch -p 1 < /tmp/sticky.patch

WORKDIR /usr/src/nginx-$NGINX_VERSION
RUN patch -p 1 < /tmp/core.patch

RUN CONFARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') && \
  sh -c "./configure --with-compat $CONFARGS \
    --add-module=/usr/src/ngx_devel_kit-${ngx_devel_kit_version} \
    --add-module=/usr/src/lua-nginx-module-${lua_nginx_version} \
    --add-module=/usr/src/nginx_ajp_module-master \
    --add-module=/usr/src/ngx_upstream_jdomain-master \
    --add-module=/usr/src/nginx-http-shibboleth-${nginx_http_shibboleth_version} \
    --add-module=/usr/src/headers-more-nginx-module-${headers_more_version} \
    --add-module=/usr/src/nginx-goodies-nginx-sticky-module-ng-${sticky_module_version_internal} " && \
  make && make install

FROM nginx:alpine
RUN apk add --no-cache luajit
# Extract the new nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
EXPOSE 80 443
CMD ["nginx", "-g", "daemon off;"]