FROM ubuntu:jammy

ARG TARGETARCH
ARG REPOSITORY_USER=""
ARG REPOSITORY_PASSWORD=""
ARG CLIENT_VERSION=1.9.3

# Install nginx as a base service to enable automation
RUN apt update && apt install -y systemd curl nginx

# Download horizon-cli with curl to allow caching
RUN curl -u "$REPOSITORY_USER:$REPOSITORY_PASSWORD" "https://repo.evertrust.io/repository/horizon-cli/horizon-cli-$CLIENT_VERSION-linux-$TARGETARCH.bin" > /usr/local/bin/horizon-cli && \
    chmod +x /usr/local/bin/horizon-cli

# Copy the Root CA used for snakeoil certs
COPY ./etc/certs/chain.pem /opt/horizon/ssl/chain.pem
RUN horizon-cli install --endpoint "https://horizon.lab" --api-id horizon-cli --api-key evertrust --root-ca-path /opt/horizon/ssl/chain.pem

# Install dummy certs
COPY ./certs /var/ssl
COPY ./etc/nginx.conf /etc/nginx/nginx.conf

RUN systemctl enable nginx

CMD ["/lib/systemd/systemd"]
