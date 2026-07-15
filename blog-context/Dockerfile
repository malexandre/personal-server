# Pinned to the toolchain era this blog was built against. The previous
# `FROM alpine` + edge mirror had rotted: current Alpine renamed/removed
# nodejs-npm and py-pygments, and gulp@3.9.1 cannot run on modern Node. Node 12
# matches the Alpine 3.12 era this blog was last built on (July 2020). Hugo is the
# non-extended (static, musl-safe) binary pinned to an era-appropriate release.
#
# Note: `gulp build` aborts with a `natives`/contextify assertion under Node's V8
# (it did so on the original Node-12 build too). It is harmless here: build.sh has
# no `set -e`, so Hugo still runs afterwards, and the CSS is committed in the theme
# — the generated site is complete and styled.
FROM node:12-alpine

RUN mkdir -p /blog
WORKDIR /blog

# Tooling + native-build deps so gulp-imagemin can compile its binaries on musl.
RUN apk add --no-cache \
    git openssh-client python3 py3-pygments \
    build-base file nasm autoconf automake libtool zlib-dev libpng-dev

# Hugo (non-extended = static Go binary, runs on musl), pinned.
RUN wget -qO- https://github.com/gohugoio/hugo/releases/download/v0.62.0/hugo_0.62.0_Linux-64bit.tar.gz \
    | tar -xz -C /usr/local/bin hugo

# yarn is already bundled in the node image; only gulp is needed globally.
RUN npm install -g gulp@3.9.1
RUN git clone --recursive https://github.com/malexandre/malexandre-blog.git .
RUN yarn
RUN apk del build-base file nasm autoconf automake libtool zlib-dev libpng-dev

ADD build.sh /blog/build.sh

CMD ["sh", "build.sh"]
