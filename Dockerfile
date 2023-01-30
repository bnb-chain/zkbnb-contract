#The docker file helps to launch a L1 independant of this project
FROM ethereumoptimism/hardhat

WORKDIR /
COPY . .

RUN apk add git;
RUN yarn install --non-interactive --frozen-lockfile
RUN yarn run compile

EXPOSE 8545

#Run the L1 hardhat node. L1 will be served at localhost:8545
CMD [ "yarn", "run", "node" ]
