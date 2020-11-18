FROM python:3.6 as BASE


#########################################
FROM BASE as BUILDER

WORKDIR /install
COPY requirements /requirements/
RUN pip install --prefix=/install -r /requirements/dev.txt


#########################################
FROM BASE

ENV CONDUIT_SECRET=changeme
ENV FLASK_APP=/app/autoapp.py
ENV FLASK_DEBUG=1
ENV DATABASE_URL=postgresql://postgres:changeme@host.docker.internal:5432/realworld

EXPOSE 5000

WORKDIR /app

# copy the content of the local src directory to the working directory
COPY --from=BUILDER /install /usr/local
COPY autoapp.py   /app/
COPY conduit      /app/conduit/
COPY tests        /app/tests/
COPY requirements /app/requirements/

# command to run on container start
CMD [ "flask", "run", "--with-threads", "--host", "0.0.0.0" ]