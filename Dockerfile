FROM node:0.10

# RUN apt-get update && apt-get install -y --no-install-recommends build-essential libssl-dev \
#         && rm -rf /var/lib/apt/lists/*

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# RUN curl https://raw.githubusercontent.com/creationix/nvm/v0.16.1/install.sh | sh
# RUN nvm install 0.10.25
# RUN nvm use 0.10.25
RUN git clone https://github.com/UNOMP/unified-node-open-mining-portal.git unomp
WORKDIR /usr/src/app/unomp
RUN npm update

EXPOSE 80 3008 3032 3256
CMD [ "node", "init.js" ]
