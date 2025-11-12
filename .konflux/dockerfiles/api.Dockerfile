ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.24
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:53ea1f6d835898acda5becdb3f8b1292038a480384bbcf994fc0bcf1f7e8eaf7

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/hub

COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD

ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/hub-api-server \
    ./api/cmd/api

FROM $RUNTIME
ARG VERSION=hub-api-next

RUN microdnf install -y openssh-clients git shadow-utils

COPY --from=builder /tmp/hub-api-server /ko-app/hub-api-server
COPY head ${KO_DATA_PATH}/HEAD

EXPOSE 8000

LABEL \
    com.redhat.component="openshift-pipelines-hub-api-container" \
    name="openshift-pipelines/pipelines-hub-api-rhel9" \
    version=$VERSION \
    summary="Red Hat OpenShift Pipelines Hub API" \
    maintainer="pipelines-extcomm@redhat.com" \
    description="Red Hat OpenShift Pipelines Hub API" \
    io.k8s.display-name="Red Hat OpenShift Pipelines Hub API" \
    io.k8s.description="Red Hat OpenShift Pipelines Hub API" \
    io.openshift.tags="pipelines,tekton,openshift"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/hub-api-server"]