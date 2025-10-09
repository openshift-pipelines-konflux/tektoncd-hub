ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=registry.redhat.io/ubi8/ubi:latest@sha256:2f698e145dd30ac9f611b8984b910640bc210fae476dc36aa9ba200fad2a30ed

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
ARG VERSION=hub-api-1.17.2

RUN dnf install -y openssh-clients git shadow-utils

COPY --from=builder /tmp/hub-api-server /ko-app/hub-api-server
COPY head ${KO_DATA_PATH}/HEAD

EXPOSE 8000

LABEL \
    com.redhat.component="openshift-pipelines-hub-api-container" \
    name="openshift-pipelines/pipelines-hub-api-rhel8" \
    version=$VERSION \
    summary="Red Hat OpenShift Pipelines Hub API" \
    maintainer="pipelines-extcomm@redhat.com" \
    description="Red Hat OpenShift Pipelines Hub API" \
    io.k8s.display-name="Red Hat OpenShift Pipelines Hub API" \
    io.k8s.description="Red Hat OpenShift Pipelines Hub API" \
    io.openshift.tags="pipelines,tekton,openshift" \
    cpe="cpe:/a:redhat:openshift_pipelines:1.17::el8"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/hub-api-server"]
