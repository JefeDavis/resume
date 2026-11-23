# syntax=docker/dockerfile:1

# The operator injects resume content (data/) via ConfigMap and relies on Hugo
# rendering at runtime, so the final image must ship Hugo itself. Modern Hugo no
# longer bundles a Sass transpiler, so Dart Sass is fetched and placed on PATH.

# ---- stage: fetch Dart Sass (required by Hugo to transpile SCSS) ----
FROM cgr.dev/chainguard/hugo:latest-dev AS sass
ARG DART_SASS_VERSION=1.108.2
WORKDIR /tmp
RUN case "$(uname -m)" in \
      x86_64)  sass_arch=x64 ;; \
      aarch64) sass_arch=arm64 ;; \
      *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    wget -qO dart-sass.tar.gz \
      "https://github.com/sass/dart-sass/releases/download/${DART_SASS_VERSION}/dart-sass-${DART_SASS_VERSION}-linux-${sass_arch}.tar.gz"; \
    tar -xzf dart-sass.tar.gz; \
    rm dart-sass.tar.gz

# ---- runtime: Chainguard Hugo + Dart Sass, serving live from mounted data ----
FROM cgr.dev/chainguard/hugo:latest-dev

COPY --from=sass /tmp/dart-sass /opt/dart-sass
# Confine every writable path Hugo needs to /tmp so the container can run with a
# read-only root filesystem; the operator only needs to mount an emptyDir at /tmp.
ENV PATH="/opt/dart-sass:${PATH}" \
    HUGO_CACHEDIR="/tmp/hugo/cache" \
    HUGO_RESOURCEDIR="/tmp/hugo/resources"

# Site source owned by the nonroot user. data/ ships as a default and is
# overridden by the operator's ConfigMap mount at runtime. Nothing is written
# under /site at runtime (see --noBuildLock / --renderToMemory below).
WORKDIR /site
COPY --chown=65532:65532 assets/     /site/assets/
COPY --chown=65532:65532 i18n/       /site/i18n/
COPY --chown=65532:65532 layouts/    /site/layouts/
COPY --chown=65532:65532 static/     /site/static/
COPY --chown=65532:65532 data/       /site/data/
COPY --chown=65532:65532 config.toml /site/config.toml

EXPOSE 1313

ENTRYPOINT ["hugo"]
# Data arrives via ConfigMap module mounts (see operator config.toml), which Hugo
# resolves at startup; content changes roll the pod rather than live-reload.
# --noBuildLock / --renderToMemory: avoid writing a lock file and the public/ dir
#   under /site, so the root filesystem can stay read-only.
CMD ["server", "--source", "/site", "--bind", "0.0.0.0", "--disableFastRender", "--noBuildLock", "--renderToMemory"]
