# =================================================================
#
# Authors: Ben Webb <bwebb@lincolninst.edu>
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

from dagster import job, op
from wqie.ops.fetch import fetch_site_metadata
from wqie.ops.transform import transform_stations, publish_station_collection
from wqie.partitions import county_partitions


@op
def fetch_and_process_stations(context):
    """Fetch and process stations for a single county partition."""

    # Extract partition key (county)
    county = context.partition_key

    # Fetch and process data
    site_details = fetch_site_metadata(county)
    sites = transform_stations(site_details)
    return publish_station_collection(sites)


@job(partitions_def=county_partitions)
def process_county_stations():
    """Job to process stations for a single county partition."""
    fetch_and_process_stations()
