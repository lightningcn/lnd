FROM golang:1.12.4-alpine3.9 as builder

# Force Go to use the cgo based DNS resolver. This is required to ensure DNS
# queries required to connect to linked containers succeed.
ENV GODEBUG netdns=cgo
ENV GOARM=6	GOARCH=arm

# Install dependencies and build the binaries.
RUN apk add --no-cache \
    git \
    make \
    build-base

WORKDIR /go/src/github.com/lightningnetwork/lnd
COPY . .

RUN make \
&&  make install

# Start a new, final image.
FROM arm32v6/alpine:3.9.3 as final

# Force Go to use the cgo based DNS resolver. This is required to ensure DNS
# queries required to connect to linked containers succeed.
ENV GODEBUG netdns=cgo
COPY qemu-arm-static /usr/bin/qemu-arm-static

# Add bash and ca-certs, for quality of life and SSL-related reasons.
RUN apk --no-cache add \
    bash \
    ca-certificates

ENV LND_DATA /data
ENV LND_BITCOIND /deps/.bitcoin
ENV LND_LITECOIND /deps/.litecoin
ENV LND_BTCD /deps/.btcd

RUN mkdir "$LND_DATA" && \
    mkdir "/deps" && \
    mkdir "$LND_BITCOIND" && \
    mkdir "$LND_LITECOIND" && \
    mkdir "$LND_BTCD" && \
    ln -sfn "$LND_DATA" /root/.lnd && \
    ln -sfn "$LND_BITCOIND" /root/.bitcoin && \
    ln -sfn "$LND_LITECOIND" /root/.litecoin && \
    ln -sfn "$LND_BTCD" /root/.btcd

# Define a root volume for data persistence.
VOLUME /data

# Copy the binaries from the builder image.
COPY --from=builder /go/bin/linux_arm/lncli /bin/
COPY --from=builder /go/bin/linux_arm/lnd /bin/

COPY docker-entrypoint.sh /docker-entrypoint.sh
# Specify the start command and entrypoint as the lnd daemon.
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["lnd"] 
