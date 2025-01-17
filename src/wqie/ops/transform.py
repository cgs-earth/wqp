# =================================================================
#
# Authors: Ben Webb <bwebb@lincolninst.edu>
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================


from dagster import op
from io import TextIOWrapper, BytesIO
from csv import DictReader
from zipfile import ZipFile
from typing import Set

@op
def parse_sites_from_metadata(metadata_zip: BytesIO) -> Set[str]:
    """
    Extract site identifiers from metadata.
    """
    zipfiles = ZipFile(metadata_zip)
    [zipfile] = zipfiles.namelist()
    sites = set()
    with zipfiles.open(zipfile) as fh:
        reader = DictReader(TextIOWrapper(fh, 'utf-8'))
        for row in reader:
            sites.add(row['MonitoringLocationIdentifier'])
    return sites