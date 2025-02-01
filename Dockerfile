# this should match the .pythonversion at the root of the repo
FROM python:3.12-slim

RUN mkdir -p /opt/dagster/dagster_home /opt/dagster/app

WORKDIR /opt/dagster/app

COPY ./requirements.txt /opt/dagster/app/requirements.txt
COPY ./pyproject.toml /opt/dagster/app/pyproject.toml

ENV DAGSTER_HOME=/opt/dagster/dagster_home/

COPY ./dagster.yaml /opt/dagster/dagster_home/
COPY src /opt/dagster/app/src

RUN pip install -e /opt/dagster/app

ENTRYPOINT [ "wqp", "jobs", "process" ] 
