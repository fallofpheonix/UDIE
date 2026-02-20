FROM postgis/postgis:16-3.4

RUN apt-get update && apt-get install -y \
    postgresql-server-dev-16 \
    build-essential \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/zachasme/h3-pg.git /tmp/h3-pg \
    && cd /tmp/h3-pg \
    && mkdir build && cd build \
    && cmake .. \
    && make && make install \
    && rm -rf /tmp/h3-pg
