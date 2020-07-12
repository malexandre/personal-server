FROM node:14.4.0-alpine3.10

RUN mkdir -p /user/app/build
WORKDIR /usr/app

RUN apk add git --no-cache
RUN git clone https://github.com/malexandre/sfbdb.git .

RUN npm install
RUN npm run build
