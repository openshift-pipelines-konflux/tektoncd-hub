# --- builder image
ARG NODEJS_BUILDER=registry.access.redhat.com/ubi9/nodejs-18@sha256:a2cc112367458e595ae93e01bb20501cd8c31a0e992d2331dd6474e21d05b007
ARG RUNTIME=registry.access.redhat.com/ubi9/nginx-122@sha256:23c1729c45bf1e3ab30e078931d20eb61b01863b068a0a971c61b9529612a2eb

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
