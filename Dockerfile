ARG VERNEMQ_VERSION="2.1.0"

FROM erlang:27.3.3-alpine AS builder 
ARG VERNEMQ_VERSION

RUN apk update && apk add --no-cache --update git libressl-dev snappy-dev build-base bsd-compat-headers
RUN mkdir /vernemq_build && \
	cd /vernemq_build && \
	git clone https://github.com/vernemq/vernemq -b ${VERNEMQ_VERSION} . && \
	make rel && \
	mkdir /vernemq_docker && \
	cd /vernemq_docker && \
	git clone https://github.com/vernemq/docker-vernemq -b 2.0.1 .


FROM alpine:3.22
ARG VERNEMQ_VERSION
COPY --from=builder /vernemq_build/_build/default/rel/vernemq /vernemq
COPY --from=builder --chown=10000:10000 /vernemq_docker/bin/vernemq.sh /usr/sbin/start_vernemq
COPY --from=builder --chown=10000:10000 /vernemq_docker/bin/join_cluster.sh /usr/sbin/join_cluster
COPY --from=builder --chown=10000:10000 /vernemq_docker/files/vm.args /vernemq/etc/vm.args

# The following commands were copied from https://github.com/vernemq/docker-vernemq/blob/2.0.1/Dockerfile.alpine
RUN apk --no-cache --update --available upgrade && \
    apk add --no-cache ncurses-libs libstdc++ jq curl bash snappy-dev nano && \
    addgroup --gid 10000 vernemq && \
    adduser --uid 10000 -H -D -G vernemq -h /vernemq vernemq && \
    install -d -o vernemq -g vernemq /vernemq

# Defaults
ENV DOCKER_VERNEMQ_KUBERNETES_LABEL_SELECTOR="app=vernemq" \
    DOCKER_VERNEMQ_LOG__CONSOLE=console \
    PATH="/vernemq/bin:$PATH" \
    VERNEMQ_VERSION="${VERNEMQ_VERSION}"

WORKDIR /vernemq

RUN chown -R 10000:10000 /vernemq && \
    ln -s /vernemq/etc /etc/vernemq && \
    ln -s /vernemq/data /var/lib/vernemq && \
    ln -s /vernemq/log /var/log/vernemq

# Ports
# 1883  MQTT
# 8883  MQTT/SSL
# 8080  MQTT WebSockets
# 44053 VerneMQ Message Distribution
# 4369  EPMD - Erlang Port Mapper Daemon
# 8888  Health, API, Prometheus Metrics
# 9100 9101 9102 9103 9104 9105 9106 9107 9108 9109  Specific Distributed Erlang Port Range

EXPOSE 1883 8883 8080 44053 4369 8888 \
       9100 9101 9102 9103 9104 9105 9106 9107 9108 9109


VOLUME ["/vernemq/log", "/vernemq/data", "/vernemq/etc"]

HEALTHCHECK CMD vernemq ping | grep -q pong

USER vernemq
CMD ["start_vernemq"]