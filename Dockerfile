FROM python:3.9-alpine AS base


#########################################
# install dependencies
#########################################
FROM base AS dependencies

WORKDIR /install

RUN apk add --no-cache \
  gcc \
  musl-dev \
  postgresql-dev \
  libffi-dev \
  postgresql-libs

COPY requirements /requirements/
RUN pip install --prefix=/install -r /requirements/prod.txt


#########################################
# install dependencies-dev
#########################################
FROM dependencies AS dependencies-dev

RUN pip install --prefix=/install -r /requirements/dev.txt


#########################################
# final for debug
#########################################
FROM base AS debug

ENV CONDUIT_SECRET=changeme
ENV FLASK_APP=/app/autoapp.py
ENV FLASK_DEBUG=1
ENV DEBUG_METRICS=1

EXPOSE 5000

RUN adduser -u 1234 -D flask

USER flask

WORKDIR /app

# copy the content of the local src directory to the working directory
COPY --from=DEPENDENCIES-DEV /install /usr/local
COPY autoapp.py   /app/
COPY conduit      /app/conduit/
COPY tests        /app/tests/
COPY requirements /app/requirements/

# command to run on container start
CMD [ "flask", "run", "--with-threads", "--host", "0.0.0.0" ]


#########################################
# final
#########################################
FROM base

ENV CONDUIT_SECRET=changeme
ENV FLASK_APP=/app/autoapp.py
ENV FLASK_DEBUG=0
ENV DEBUG_METRICS=1
ENV DATABASE_URL=postgresql://postgres:changeme@host.docker.internal:5432/realworld

EXPOSE 5000

RUN adduser -u 1234 -D flask

USER flask

WORKDIR /app

# copy the content of the local src directory to the working directory
COPY --from=DEPENDENCIES /install /usr/local
COPY autoapp.py   /app/
COPY conduit      /app/conduit/
COPY requirements /app/requirements/

# command to run on container start
CMD [ "flask", "run", "--with-threads", "--host", "0.0.0.0" ]

