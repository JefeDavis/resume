FROM klakegg/hugo:ext-alpine
COPY assets/ /site/assets/
COPY i18n/ /site/i18n/
COPY layouts/ /site/layouts/
COPY config.toml /site/
COPY static/ /site/static/
COPY data/ /site/data/

WORKDIR /site

CMD [ "server"]
