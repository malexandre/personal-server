FROM alpine

RUN mkdir -p /blog
WORKDIR /blog

RUN apk add nodejs git py-pygments openssh-client build-base file nasm autoconf --no-cache
RUN apk add --no-cache -X http://dl-4.alpinelinux.org/alpine/edge/main automake zlib-dev
RUN apk add --no-cache -X http://dl-4.alpinelinux.org/alpine/edge/community hugo
RUN npm install -g gulp yarn
RUN git clone --recursive https://github.com/malexandre/malexandre-blog.git .
RUN yarn
RUN apk del build-base file nasm autoconf automake zlib-dev

ADD build.sh /blog/build.sh

CMD ["sh", "build.sh"]
