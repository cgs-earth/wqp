# =================================================================
#
# Authors: Ben Webb <bwebb@lincolninst.edu>
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

from dagster import job, op, build_op_context
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

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python jobs.py <county1> <county2> ...")
        sys.exit(1)

    counties = sys.argv[1:]

    for county in counties:
        print(f"Starting job for county: {county}")

        context = build_op_context(partition_key=county)
        result = fetch_and_process_stations(context)

        if result:
            print(f"Successfully processed county: {county}")
        else:
            print(f"Failed to process county: {county}")
