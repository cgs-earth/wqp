# =================================================================
#
# Authors: Ben Webb <bwebb@lincolninst.edu>
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

from dagster import asset
from wqie.ops.fetch import fetch_station_metadata, fetch_site_metadata
from wqie.ops.transform import transform_stations
from wqie.partitions import county_partitions


@asset(partitions_def=county_partitions)
def county_stations(context):
    """Fetch and process stations for a single county partition."""

    # Extract the partition key (county)
    county = context.asset_partition_key_for_output()

    # Fetch and process data
    stations = fetch_station_metadata(county)
    site_details = fetch_site_metadata(
        [s["MonitoringLocationIdentifier"] for s in stations]
    )
    return transform_stations(site_details)
