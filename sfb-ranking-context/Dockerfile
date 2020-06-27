FROM node:14.4.0-alpine3.10
WORKDIR /usr/app

RUN apk add git --no-cache
RUN git clone https://github.com/malexandre/sfb-ranking.git .
RUN git init

RUN npm install
RUN npm run build

ADD build.sh ./build.sh
CMD ["sh", "build.sh"]
