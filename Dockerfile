FROM klakegg/hugo:ext-alpine
COPY themes/ /site/themes/
COPY config.toml /site/
COPY static/ /site/static/
COPY data/ /site/data/

WORKDIR /site

CMD [ "server"]