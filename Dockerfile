ARG postgres_image_version=13.1
ARG postgres_pkg_server_version=13
ARG rdkit_git_ref=Release_2021_09_4
ARG rdkit_git_url=https://github.com/rdkit/rdkit.git


FROM docker.io/postgres:${postgres_image_version} AS builder

ARG postgres_pkg_server_version
ARG rdkit_git_ref
ARG rdkit_git_url

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -yqq --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
    && curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -yqq --no-install-recommends \
        build-essential \
        cmake \
        git \
        libboost-iostreams-dev \
        libboost-regex-dev \
        libboost-serialization-dev \
        libboost-system-dev \
        libeigen3-dev \
        libfreetype6-dev \
        postgresql-server-dev-${postgres_pkg_server_version} \
        zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/RDKit-build \
    && chown postgres:postgres /opt/RDKit-build

USER postgres
WORKDIR /opt/RDKit-build

RUN git clone ${rdkit_git_url}
WORKDIR /opt/RDKit-build/rdkit
RUN git checkout ${rdkit_git_ref}

RUN cmake \
    -D RDK_BUILD_CAIRO_SUPPORT=OFF \
    -D RDK_BUILD_INCHI_SUPPORT=ON \
    -D RDK_BUILD_AVALON_SUPPORT=ON \
    -D RDK_BUILD_PYTHON_WRAPPERS=OFF \
    -D RDK_BUILD_DESCRIPTORS3D=OFF \
    -D RDK_BUILD_FREESASA_SUPPORT=OFF \
    -D RDK_BUILD_COORDGEN_SUPPORT=ON \
    -D RDK_BUILD_MOLINTERCHANGE_SUPPORT=OFF \
    -D RDK_BUILD_YAEHMOP_SUPPORT=OFF \
    -D RDK_BUILD_STRUCTCHECKER_SUPPORT=OFF \
    -D RDK_USE_URF=OFF \
    -D RDK_BUILD_PGSQL=ON \
    -D RDK_PGSQL_STATIC=ON \
    -D PostgreSQL_CONFIG=pg_config \
    -D PostgreSQL_INCLUDE_DIR=`pg_config --includedir` \
    -D PostgreSQL_TYPE_INCLUDE_DIR=`pg_config --includedir-server` \
    -D PostgreSQL_LIBRARY_DIR=`pg_config --libdir` \
    -D RDK_INSTALL_INTREE=OFF \
    -D CMAKE_INSTALL_PREFIX=/opt/RDKit \
    -D CMAKE_BUILD_TYPE=Release \
    . 
RUN make -j4

USER root
WORKDIR /opt/RDKit-build/rdkit

RUN make install
RUN /bin/bash /opt/RDKit-build/rdkit/Code/PgSQL/rdkit/pgsql_install.sh

USER postgres
WORKDIR /opt/RDKit-build/rdkit

RUN initdb -D /opt/RDKit-build/pgdata \
  && pg_ctl -D /opt/RDKit-build/pgdata -l /opt/RDKit-build/pgdata/log.txt start \
  && RDBASE="$PWD" LD_LIBRARY_PATH="$PWD/lib" ctest -j4 --output-on-failure \
  && pg_ctl -D /opt/RDKit-build/pgdata stop


ARG postgres_image_version

FROM docker.io/postgres:${postgres_image_version}

ARG postgres_pkg_server_version

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -yqq --no-install-recommends \
        libboost-iostreams-dev \
        libboost-regex-dev \
        libboost-serialization-dev \
        libboost-system-dev \
        libfreetype6-dev \
        zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/share/postgresql/${postgres_pkg_server_version}/extension/*rdkit* /usr/share/postgresql/${postgres_pkg_server_version}/extension/
COPY --from=builder /usr/lib/postgresql/${postgres_pkg_server_version}/lib/rdkit.so /usr/lib/postgresql/${postgres_pkg_server_version}/lib/rdkit.so