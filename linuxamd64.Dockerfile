FROM golang:1.13-alpine as builder

# Force Go to use the cgo based DNS resolver. This is required to ensure DNS
# queries required to connect to linked containers succeed.
ENV GODEBUG netdns=cgo

# Install dependencies and install/build lnd.
RUN apk add --no-cache --update alpine-sdk \
    git \
    make 

# Copy in the local repository to build from.
COPY . /go/src/github.com/lightningnetwork/lnd

RUN cd /go/src/github.com/lightningnetwork/lnd \
&&  make \
&&  make install tags="signrpc walletrpc chainrpc invoicesrpc"

# Start a new, final image to reduce size.
FROM alpine as final
 
EXPOSE 9735 10009

# Force Go to use the cgo based DNS resolver. This is required to ensure DNS
# queries required to connect to linked containers succeed.
ENV GODEBUG netdns=cgo

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
COPY --from=builder /go/bin/lncli /bin/
COPY --from=builder /go/bin/lnd /bin/

COPY docker-entrypoint.sh /docker-entrypoint.sh
# Specify the start command and entrypoint as the lnd daemon.
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["lnd"]
