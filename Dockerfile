# syntax=docker/dockerfile:1.0.0-experimental
FROM python:3.8-slim as base

SHELL ["/bin/bash", "-c"]

ENV PORT 5000
ENV FLASK_APP run.py
ENV FLASK_ENV production
EXPOSE 5000

FROM base as python-deps

RUN apt-get update -qq && apt-get install -y ssh git

# require a private key to access private github repositories
ARG SSH_PRIVATE_KEY
RUN mkdir /root/.ssh/
RUN echo "${SSH_PRIVATE_KEY}" > /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa
RUN touch /root/.ssh/known_hosts
RUN ssh-keyscan -T 20 github.com >> /root/.ssh/known_hosts

ADD requirements.txt .
RUN python3 -m venv .venv
RUN source .venv/bin/activate
RUN pip install -r requirements.txt

FROM base as runtime

RUN apt-get update -qq && \
  # for db connectivity
  apt-get install -y postgresql-client \
  # for healthcheck
  curl \
  && \
  apt-get clean

RUN mkdir /opt/app
WORKDIR /opt/app

COPY --from=python-deps /.venv /.venv
ENV PATH="/.venv/bin:$PATH"

COPY . .

CMD sh start.sh
# HEALTHCHECK --timeout=2s CMD test $(curl -s -o /dev/null -w "%{http_code}" localhost:5000/healthcheck) = "200"
