FROM golang:1.24.2-alpine as go_builder
RUN apk add --no-cache curl unzip

ENV PROTOBUF_VERSION=30.2 \
    GRPC_WEB_VERSION=1.5.0

RUN mkdir -p /protobuf && \
    curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protoc-${PROTOBUF_VERSION}-linux-x86_64.zip && \
    unzip protoc-${PROTOBUF_VERSION}-linux-x86_64.zip -d /protobuf && \
    rm -rf protoc-${PROTOBUF_VERSION}-linux-x86_64.zip

RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.6 && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1 && \
    go install github.com/golang/protobuf/protoc-gen-go@v1.5.4 && \
    go install github.com/envoyproxy/protoc-gen-validate@v1.2.1 && \
    cp -r $GOPATH/pkg/mod/github.com/envoyproxy/protoc-gen-validate@v1.2.1/validate  /protobuf/ && \
    mkdir -p /protobuf/google/protobuf && \
            for f in any duration descriptor empty struct timestamp wrappers type; do \
            curl -L -o /protobuf/google/protobuf/${f}.proto https://raw.githubusercontent.com/google/protobuf/master/src/google/protobuf/${f}.proto; \
            done && \
    mkdir -p /protobuf/google/api && \
        for f in annotations http; do \
        curl -L -o /protobuf/google/api/${f}.proto https://raw.githubusercontent.com/googleapis/googleapis/master/google/api/${f}.proto; \
        done

WORKDIR /grpc-web

RUN mkdir -p /grpc-web && \
    curl -LO https://github.com/grpc/grpc-web/releases/download/${GRPC_WEB_VERSION}/protoc-gen-grpc-web-${GRPC_WEB_VERSION}-linux-x86_64 && \
    mv protoc-gen-grpc-web-${GRPC_WEB_VERSION}-linux-x86_64 protoc-gen-grpc-web && \
    chmod +x /grpc-web/protoc-gen-grpc-web


FROM node:23.0.0-bullseye-slim

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

COPY --from=go_builder /go /go
COPY --from=go_builder /usr/local/go /usr/local/go
COPY --from=go_builder /protobuf /protobuf
COPY --from=go_builder /protobuf/bin/protoc /usr/bin/protoc
COPY --from=go_builder /grpc-web/protoc-gen-grpc-web /usr/bin/protoc-gen-grpc-web

RUN npm install -g protoc-gen-js
RUN npm install -g ts-protoc-gen

ENTRYPOINT ["/usr/bin/protoc", "-I/protobuf"]
