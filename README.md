# PostgreSQL Docker Image with RDKit Cartridge

This is a PostgreSQL Docker image with the RDKit cartridge installed.

Based on [docker-library/postgres](https://github.com/docker-library/postgres) and [mcs07/docker-postgres-rdkit](https://github.com/mcs07/docker-postgres-rdkit), [rdkit](https://github.com/rdkit/rdkit).


This image inherits from the [official postgres image](https://hub.docker.com/_/postgres/), and therefore has all the same environment variables for configuration, and can be extended by adding entrypoint scripts to the `/docker-entrypoint-initdb.d` directory to be run on first launch.

## Running

Start Postgres server running in the background:

    docker run --name mypostgres -p 5432:5432 -e POSTGRES_PASSWORD=mypassword -d vladkmrdnv/postgres-rdkit

Or run with an application via Docker Compose:

```yaml
version: "3.0"
services:

  db:
    image: vladkmrdnv/postgres-rdkit
    restart: always
    ports:
    - 5432:5432
    environment:
      POSTGRES_PASSWORD: mypassword
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql

  adminer:
    image: adminer
    restart: always
    ports:
      - 8080:8080

volumes:
  pgdata:
```

This image exposes port 5432 (the postgres port), so standard container linking will make it automatically available to the linked containers.

## Environment Variables

- `POSTGRES_PASSWORD`: Superuser password for PostgreSQL.
- `POSTGRES_USER`: Superuser username (default `postgres`).
- `POSTGRES_DB`: Default database that is created when the image is first started.
- `PGDATA`: Location for the database files (default `/var/lib/postgresql/data`).

See the [official postgres image](https://hub.docker.com/_/postgres/) for more details.

## Building

A multi-stage docker build is used to produce a lightweight production image without all the build dependencies. 
Required postgres versions and RDkit version using ARG.
- `postgres_image_version`: Version of Docker image
- `postgres_pkg_server_version`: Version of Postgres-server pkg. Must be Major from docker image version
- `rdkit_git_ref`: RDKit version

To build, run:

    docker build -t postgres-rdkit .