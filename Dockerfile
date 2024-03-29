FROM mjmckinnon/ubuntubuild:latest as builder

ARG VERSION="v0.17.3"
ARG GITREPO="https://github.com/BTCGPU/BTCGPU.git"
ARG GITNAME="BTCGPU"
ARG COMPILEFLAGS="--disable-tests --disable-bench --enable-cxx --disable-shared --with-pic --disable-wallet --without-gui --without-miniupnpc"
ENV DEBIAN_FRONTEND="noninteractive"

# Get the source from Github
WORKDIR /root
RUN git clone ${GITREPO} --branch ${VERSION}
WORKDIR /root/${GITNAME}
# Copy some kludge patches to make this thing compiled under Ubuntu 22.04
COPY ./*.patch ./
RUN \
    echo "** applying patches **" \
    && git apply -v ./btg-*.patch \
    && echo "** compile **" \
    && ./autogen.sh \
    && ./configure CXXFLAG="-O2" LDFLAGS=-static-libstdc++ ${COMPILEFLAGS} \
    && make \
    && echo "** install and strip the binaries **" \
    && mkdir -p /dist-files \
    && make install DESTDIR=/dist-files \
    && strip /dist-files/usr/local/bin/* \
    && echo "** removing extra lib files **" \
    && find /dist-files -name "lib*.la" -delete \
    && find /dist-files -name "lib*.a" -delete \
    && cd .. && rm -rf ${GITREPO}

# Final stage
FROM ubuntu:22.04
LABEL maintainer="Michael J. McKinnon <mjmckinnon@gmail.com>"

# Put our entrypoint script in
COPY ./docker-entrypoint.sh /

# Copy the compiled files
COPY --from=builder /dist-files/ /

ENV DEBIAN_FRONTEND="noninteractive"
RUN \
    echo "** update and install dependencies **" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       gosu \
       libboost-filesystem1.74.0 \
       libboost-thread1.74.0 \
       libevent-2.1-7 \
       libevent-pthreads-2.1-7 \
       libboost-program-options1.74.0 \
       libboost-chrono1.74.0 \
       libb2-1 \
       libczmq4 \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/ \
    && rm -rf /tmp/* /var/tmp/*

RUN \
    echo "** setup the btcgold user **" \
    && groupadd -r btcgold \
    && useradd --no-log-init -m -d /data -r -g btcgold btcgold

ENV DATADIR="/data"
EXPOSE 8338
VOLUME /data

USER btcgold
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["bgoldd", "-printtoconsole"]
