FROM jrottenberg/ffmpeg

#lua and stuff to build imagemagick/lua-imagemagick
RUN  DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
    git \
    lua5.1 \
    luajit \
    cmake \
    luajit-5.1-dev \
    wget build-essential \
    ghostscript \
    luarocks



RUN apt-get update && apt-get install -y libmagickwand-dev curl libssl-dev uuid-dev
RUN luarocks install luasec
RUN luarocks install --server=http://luarocks.org/dev giflib && \
    luarocks install redis-lua && \
    luarocks install luasocket && \
    luarocks install magick && \
    luarocks install lua-cjson && \
    luarocks install luasec && \
    luarocks install magick && \
    luarocks install lua-cjson && \
    luarocks install sha1


#RUN apt-get update && apt-get build-dep -y giflib-dbg

ENV GIFLIB_VERSION 5.1.4
WORKDIR /tmp
RUN curl -sOL http://prdownloads.sourceforge.net/giflib/giflib-${GIFLIB_VERSION}.tar.gz \
	&& tar xzf giflib-${GIFLIB_VERSION}.tar.gz \
	&& cd giflib-${GIFLIB_VERSION} \
	&& ./configure --prefix=${DEST} --enable-shared --disable-static \
	&& make \
	&& make install-strip


RUN luarocks install --server=http://luarocks.org/dev giflib
RUN wget https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && \
    pip install imgurpython

RUN apt-get update && apt-get install -y ca-certificates stunnel4


RUN mkdir -p /var/www && mkdir /lua
WORKDIR /lua
VOLUME /var/www
#CMD [ "luajit", "imgconverter.lua" ]

ENTRYPOINT ["/lua/start.sh"]
