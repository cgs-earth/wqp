# =================================================================
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

from dagster import Definitions
from wqie.assets import county_stations
from wqie.jobs import process_county_stations


defs = Definitions(
    assets=[county_stations],
    jobs=[process_county_stations],
)
