FROM nginx:alpine AS builder

# nginx:alpine contains NGINX_VERSION environment variable, like so:
# ENV NGINX_VERSION 1.15.0

ENV ngx_devel_kit_version 0.3.1
ENV lua_nginx_version 0.10.15
ENV luagit2_vesion 2.1-20190626
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
  geoip-dev \
  build-base

# Download sources
RUN curl -L -o /tmp/nginx.tar.gz "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" && \
  curl -L -o /tmp/ngx_devel_kit-${ngx_devel_kit_version}.tar.gz https://github.com/simpl/ngx_devel_kit/archive/v${ngx_devel_kit_version}.tar.gz && \
  curl -L -o /tmp/lua-nginx-module-${lua_nginx_version}.tar.gz https://github.com/openresty/lua-nginx-module/archive/v${lua_nginx_version}.tar.gz && \
  curl -L -o /tmp/nginx-goodies-nginx-sticky-module-ng-${sticky_module_version}.tar.gz https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng/get/${sticky_module_version}.tar.gz && \
  curl -L -o /tmp/nginx-http-shibboleth-${nginx_http_shibboleth_version}.tar.gz https://github.com/nginx-shib/nginx-http-shibboleth/archive/v${nginx_http_shibboleth_version}.tar.gz && \
  curl -L -o /tmp/luajit2-${luagit2_vesion}.tar.gz https://github.com/openresty/luajit2/archive/v${luagit2_vesion}.tar.gz && \
  curl -L -o /tmp/headers-more-nginx-module-${headers_more_version}.tar.gz https://github.com/openresty/headers-more-nginx-module/archive/v${headers_more_version}.tar.gz


# Last Commits for master branch on Feb 28, 2015
COPY nginx_ajp_module-master.tar.gz /tmp/nginx_ajp_module-master.tar.gz
# Latest commit 1a92c67  on 19 Jul 2017
COPY ngx_upstream_jdomain-master.tar.gz  /tmp/ngx_upstream_jdomain-master.tar.gz
COPY core.patch /tmp/core.patch
COPY shibboleth.patch  /tmp/shibboleth.patch
COPY sticky.patch /tmp/sticky.patch

# unarchive source codes
RUN mkdir -p /usr/src
WORKDIR /usr/src
RUN tar -zxf /tmp/nginx.tar.gz && \
  tar -zxf /tmp/ngx_devel_kit-${ngx_devel_kit_version}.tar.gz && \
  tar -zxf /tmp/lua-nginx-module-${lua_nginx_version}.tar.gz && \
  tar -zxf /tmp/luajit2-${luagit2_vesion}.tar.gz && \
  tar -zxf /tmp/nginx-goodies-nginx-sticky-module-ng-${sticky_module_version}.tar.gz && \
  tar -zxf /tmp/nginx-http-shibboleth-${nginx_http_shibboleth_version}.tar.gz && \
  tar -zxf /tmp/headers-more-nginx-module-${headers_more_version}.tar.gz && \
  tar -zxf /tmp/nginx_ajp_module-master.tar.gz && \
  tar -zxf /tmp/ngx_upstream_jdomain-master.tar.gz
COPY ngx_upstream_resolveMK ngx_upstream_resolveMK

RUN patch -p 1 < /tmp/shibboleth.patch
RUN patch -p 1 < /tmp/sticky.patch

RUN cd /usr/src/luajit2-${luagit2_vesion} && make -e PREFIX=/usr && make -e PREFIX=/usr install
ENV LUAJIT_INC /usr/include/luajit-2.1
ENV LUAJIT_LIB /usr/lib

WORKDIR /usr/src/nginx-$NGINX_VERSION
RUN patch -p 1 < /tmp/core.patch

# Reuse same cli arguments as the nginx:alpine image used to build
RUN CONFARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') && \
  sh -c "./configure --with-compat $CONFARGS \
    --add-module=/usr/src/ngx_devel_kit-${ngx_devel_kit_version} \
    --add-module=/usr/src/lua-nginx-module-${lua_nginx_version} \
    --add-module=/usr/src/nginx_ajp_module-master \
    --add-module=/usr/src/ngx_upstream_jdomain-master \
    --add-module=/usr/src/nginx-http-shibboleth-${nginx_http_shibboleth_version} \
    --add-module=/usr/src/headers-more-nginx-module-${headers_more_version} \
    --add-module=/usr/src/nginx-goodies-nginx-sticky-module-ng-${sticky_module_version_internal} \
    --add-module=/usr/src/ngx_upstream_resolveMK " && \
  make && make install

WORKDIR /

FROM nginx:alpine
ENV luagit2_vesion 2.1-20190626

RUN apk add gcc
# Extract the new nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/bin/luajit-2.1.0-beta3 /usr/bin/luajit-2.1.0-beta3
COPY --from=builder /usr/lib/libluajit-5.1.so.2.1.0 /usr/lib/libluajit-5.1.so.2.1.0
COPY --from=builder /usr/share/man/man1/luajit.1 /usr/share/man/man1/luajit.1
# cd src/jit && install -m 0644 bc.lua bcsave.lua dump.lua p.lua v.lua zone.lua dis_x86.lua dis_x64.lua dis_arm.lua dis_arm64.lua dis_arm64be.lua dis_ppc.lua dis_mips.lua dis_mipsel.lua dis_mips64.lua dis_mips64el.lua vmdef.lua /usr/share/luajit-2.1.0-beta3/jit
COPY --from=builder /usr/src/luajit2-${luagit2_vesion}/src/jit /usr/share/luajit-2.1.0-beta3/jit
RUN ln -sf libluajit-5.1.so.2.1.0 /usr/lib/libluajit-5.1.so && \
    ln -sf libluajit-5.1.so.2.1.0 /usr/lib/libluajit-5.1.so.2 && \
    ln -sf luajit-2.1.0-beta3 /usr/bin/luajit

COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80 443
CMD ["nginx", "-g", "daemon off;"]
