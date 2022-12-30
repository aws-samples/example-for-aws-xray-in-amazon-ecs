FROM node:16.15.0-buster-slim

RUN apt update

WORKDIR /usr/src/app

COPY package.json .
RUN npm install

COPY server.js .

CMD [ "node", "server.js" ]
EXPOSE 80