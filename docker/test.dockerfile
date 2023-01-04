FROM paritytech/ci-linux:production AS builder

LABEL maintainer="imbue-dev"
ARG GIT_BRANCH="main"
ARG GIT_CLONE_DEPTH="--depth 1"
ENV DEBIAN_FRONTEND noninteractive

WORKDIR /builds
RUN git clone --recursive https://github.com/samelamin/cumulus
WORKDIR /builds/cumulus
RUN git checkout warp_sync_docker
RUN cargo build --release
FROM debian:buster-slim as collator
RUN apt-get update && apt-get install jq curl bash -y && \
    curl -sSo /wait-for-it.sh https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh && \
    chmod +x /wait-for-it.sh && \
    curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
    apt-get install -y nodejs && \
    npm install --global yarn && \
    yarn global add @polkadot/api-cli@0.10.0-beta.14

FROM docker.io/library/ubuntu:20.04
# install tools and dependencies
RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
	libssl1.1 \
	ca-certificates \
	curl && \
	# apt cleanup
	apt-get autoremove -y && \
	apt-get clean && \
	find /var/lib/apt/lists/ -type f -not -name lock -delete; \
	# add user and link ~/.local/share/test-parachain to /data
	useradd -m -u 10000 -U -s /bin/sh -d /test-parachain test-parachain && \
	mkdir -p /data /test-parachain/.local/share && \
	chown -R test-parachain:test-parachain /data && \
	ln -s /data /test-parachain/.local/share/test-parachain && \
	mkdir -p /specs && \
	mkdir -p /cfg


FROM paritypr/test-parachain:2051-8d5cc119

## add test-parachain binary to the docker image
COPY --from=builder \
    /builds/cumulus/target/release/polkadot-parachain /usr/local/bin
COPY --from=builder \
    /builds/cumulus/target/release/test-parachain /usr/local/bin
#COPY --from=builder \
#    /builds/cumulus/parachains/chain-specs/*.json /specs/
#
## check if executable works in this container
#RUN /usr/local/bin/test-parachain --version
#RUN touch /tmp/finished.txt
RUN /usr/local/bin/test-parachain --version
EXPOSE 30333 9933 9944
VOLUME ["/test-parachain"]
ENTRYPOINT ["/usr/local/bin/test-parachain"]

#bash -c test-parachain build-spec  --disable-default-bootnode > /cfg/rococo-local-plain.json && echo done > /tmp/zombie-tmp-done && until [ -f /tmp/finished.txt ]; do echo waiting for copy files to finish; sleep 1; done; echo copy files has finished