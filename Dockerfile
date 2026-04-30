FROM alpine:3.23.4

RUN apk update
RUN apk upgrade

# required by qemu
RUN apk add\
 make\
 samurai\
 perl\
 python3\
 gcc\
 libc-dev\
 pkgconf\
 linux-headers\
 glib-dev glib-static\
 zlib-dev zlib-static\
 pcre2-dev pcre2-static\
 flex\
 bison

# required by build
RUN apk add bash xz git

WORKDIR /work
COPY build build
RUN /work/build
