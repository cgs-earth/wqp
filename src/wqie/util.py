import re
import os
import hashlib
from typing import Union, Any
from uuid import UUID

def get_typed_value(value) -> Union[float, int, str]:
    """
    Derive true type from data value

    :param value: value

    :returns: value as a native Python data type
    """

    try:
        if '.' in value:  # float?
            value2 = float(value)
        elif len(value) > 1 and value.startswith('0'):
            value2 = value
        else:  # int?
            value2 = int(value)
    except ValueError:  # string (default)?
        value2 = value

    return value2

def extract_coord(p):
    """
    helper function to extract coordinate

    :param input: string of coordinate

    :returns: types coordinate value
    """
    return get_typed_value(''.join(re.findall(r'[-\d\.]+', p)))


def clean_word(input: str, delim: str = ' ') -> str:
    """
    helper function to make clean words

    :param input: string of source

    :returns: str of resulting uuid
    """
    return delim.join(re.findall(r'\w+', input))

def url_join(*parts: str) -> str:
    """
    helper function to join a URL from a number of parts/fragments.
    Implemented because urllib.parse.urljoin strips subpaths from
    host urls if they are specified

    Per https://github.com/geopython/pygeoapi/issues/695

    :param parts: list of parts to join

    :returns: str of resulting URL
    """

    return '/'.join([str(p).strip().strip('/') for p in parts]).rstrip('/')

def get_env(key: str, fallback: Any = None) -> str:
    """Fetch environment variable"""
    val = os.environ.get(key, fallback)
    if val is None:
        raise Exception(f"Missing ENV var: {key}")

    return val

def make_uuid(input: str, raw: bool = False) -> UUID:
    """
    helper function to make uuid

    :param input: string of source
    :param raw: bool of str casting

    :returns: str of resulting uuid
    """
    _uuid = UUID(hex=hashlib.md5(input.encode('utf-8')).hexdigest())
    if raw:
        return _uuid
    else:
        return str(_uuid)
