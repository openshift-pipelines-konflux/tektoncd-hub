# --- builder image
ARG NODEJS_BUILDER=registry.access.redhat.com/ubi9/nodejs-18@sha256:d9ae385958d3db69a4a6db3bae55a60bcf82fad7bb036d92b4137add2c093926
ARG RUNTIME=registry.access.redhat.com/ubi9/nginx-122@sha256:cdb77f7a9c5c3013b524b9e774fa8c843d16dd85d920429ac02d048cbe804992

FROM $NODEJS_BUILDER AS builder

ARG REMOTE_SOURCE=/go/src/github.com/tektoncd/hub

WORKDIR $REMOTE_SOURCE

COPY upstream .
USER root
RUN chmod -R g+w $REMOTE_SOURCE
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo foo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done

WORKDIR $REMOTE_SOURCE/ui

RUN npm clean-install --legacy-peer-deps && \
    npm run build

# --- runtime image
FROM $RUNTIME
ARG REMOTE_SOURCE=/go/src/github.com/tektoncd/hub

COPY --from=builder $REMOTE_SOURCE/ui/build /opt/app-root/src
COPY --from=builder --chown=1001 $REMOTE_SOURCE/ui/image/start.sh /usr/bin/
ENV BASE_PATH="/opt/app-root/src"
ARG VERSION=hub-main

USER root
RUN chmod ugo+rw /opt/app-root/src/config.js && \
    chown nginx:nginx /opt/app-root/src/config.js && \
    chmod +x /usr/bin/start.sh
USER nginx

EXPOSE 8080

COPY --from=builder --chown=1001 $REMOTE_SOURCE/ui/image/location.locations "${NGINX_DEFAULT_CONF_PATH}"/location.conf

CMD /usr/bin/start.sh

LABEL \
    com.redhat.component="openshift-pipelines-hub-ui-container" \
    name="openshift-pipelines/pipelines-hub-ui-rhel8" \
    version=$VERSION \
    summary="Red Hat OpenShift Pipelines Hub UI" \
    maintainer="pipelines-extcomm@redhat.com" \
    description="Red Hat OpenShift Pipelines Hub UI" \
    io.k8s.display-name="Red Hat OpenShift Pipelines Hub UI" \
    io.k8s.description="Red Hat OpenShift Pipelines Hub UI" \
    io.openshift.tags="pipelines,tekton,openshift"
