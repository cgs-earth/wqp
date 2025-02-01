# =================================================================
#
# Authors: Ben Webb <bwebb@lincolninst.edu>
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

import click
from dagster import job, op, build_op_context
import os
import sys

from wqp.ops.fetch import fetch_station_metadata
from wqp.ops.transform import transform_stations, publish_station_collection
from wqp.partitions import county_partitions


@op
def fetch_and_process_stations(context) -> bool:
    """Fetch and process stations for a single county partition."""

    # Extract partition key (county)
    county = context.partition_key

    # Fetch and process data
    site_details = fetch_station_metadata(county)
    sites = transform_stations(site_details)
    return publish_station_collection(sites)


@job(partitions_def=county_partitions)
def process_county_stations():
    """Job to process stations for a single county partition."""
    fetch_and_process_stations()


def process_county(county: str):
    context = build_op_context(partition_key=county)
    result = fetch_and_process_stations(context)
    if result:
        print(f"Successfully processed county: {county}")
    else:
        print(f"Failed to process county: {county}")


@click.group()
def jobs():
    """Jobs management"""
    pass


@click.command()
@click.pass_context
@click.argument("counties", required=False, nargs=-1)
def process(ctx, counties):
    TASK_INDEX = int(os.environ.get("CLOUD_RUN_TASK_INDEX", -1))
    if list(counties):
        click.echo(f'Counties: {", ".join(counties)}')
        for county in list(counties):
            process_county(county=county)

    elif TASK_INDEX >= 0:
        county = county_partitions.get_partition_keys()[TASK_INDEX]
        click.echo(f'County: {county}')
        process_county(county=county)

    else:
        raise RuntimeError('No counties found to process')

jobs.add_command(process)
