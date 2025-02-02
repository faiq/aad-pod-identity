ARG BUILDPLATFORM="linux/amd64"
ARG BUILDERIMAGE="golang:1.17"
ARG BASEIMAGE=gcr.io/distroless/static:nonroot

FROM --platform=$BUILDPLATFORM $BUILDERIMAGE as builder

ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH

WORKDIR /go/src/github.com/Azure/aad-pod-identity
ADD . .
RUN go mod download
ARG IMAGE_VERSION
RUN export GOOS=$TARGETOS && \
    export GOARCH=$TARGETARCH && \
    export GOARM=$(echo ${TARGETPLATFORM} | cut -d / -f3 | tr -d 'v') && \
    make build

FROM k8s.gcr.io/build-image/debian-iptables:bullseye-v1.2.0 AS nmi
# upgrading libssl1.1 due to CVE-2021-3711 and CVE-2021-3712
# upgrading libgmp10 due to CVE-2021-43618
# upgrading bsdutils due to CVE-2021-3995 and CVE-2021-3996
# upgrading libc-bin and libc6 due to CVE-2021-33574, CVE-2022-23218, CVE-2022-23219 and CVE-2021-43396
# upgrading libsystemd0 and libudev1 due to CVE-2021-3997
RUN clean-install ca-certificates libssl1.1 libgmp10 bsdutils libc6 libc-bin libsystemd0 libudev1
COPY --from=builder /go/src/github.com/Azure/aad-pod-identity/bin/aad-pod-identity/nmi /bin/
RUN useradd -u 10001 nonroot
USER nonroot
ENTRYPOINT ["nmi"]

FROM $BASEIMAGE AS mic
COPY --from=builder /go/src/github.com/Azure/aad-pod-identity/bin/aad-pod-identity/mic /bin/
ENTRYPOINT ["mic"]

FROM $BASEIMAGE AS demo
COPY --from=builder /go/src/github.com/Azure/aad-pod-identity/bin/aad-pod-identity/demo /bin/
ENTRYPOINT ["demo"]

FROM $BASEIMAGE AS identityvalidator
COPY --from=builder /go/src/github.com/Azure/aad-pod-identity/bin/aad-pod-identity/identityvalidator /bin/
ENTRYPOINT ["identityvalidator"]
