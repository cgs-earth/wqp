# =================================================================
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

__version__ = '0.1.dev1'

import click
from dagster import Definitions

from wqp.jobs import process_county_stations, jobs


defs = Definitions(
    jobs=[process_county_stations],
)


@click.group()
@click.version_option(version=__version__)
def cli():
    """WQP"""
    pass


cli.add_command(jobs)
