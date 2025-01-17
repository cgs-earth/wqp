# =================================================================
#
# Authors: Colton Loftus <cloftus@lincolninst.edu>
# Authors: Ben Webb <bwebb@lincolninst.edu>
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

from wqie.util import get_env

API_BACKEND_URL = get_env(
    "API_BACKEND_URL", fallback="http://localhost:8888/FROST-Server/v1.1"
)
GEOCONNEX_URL = "https://geoconnex.us"
NLDI_URL = "https://labs.waterdata.usgs.gov/api/nldi"
STATION_URL = 'https://www.waterqualitydata.us/data/Station/search'
RESULTS_URL = 'https://www.waterqualitydata.us/data/Result/search'
