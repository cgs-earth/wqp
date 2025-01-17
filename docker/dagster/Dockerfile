# this should match the .pythonversion at the root of the repo
FROM python:3.12-slim

RUN mkdir -p /opt/dagster/dagster_home /opt/dagster/app

COPY ../requirements.txt requirements.txt

RUN pip install -r requirements.txt

ENV DAGSTER_HOME=/opt/dagster/dagster_home/

COPY ../dagster.yaml /opt/dagster/dagster_home/
COPY ../pyproject.toml /opt/dagster/app/pyproject.toml
COPY userCode /opt/dagster/app/userCode

WORKDIR /opt/dagster/app

EXPOSE 3000

ENTRYPOINT ["dagster-webserver", "-h", "0.0.0.0", "-p", "3000"]
