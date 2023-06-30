#!/usr/bin/env python3
# compose v2ray config dynamically


# %% Setup
from pathlib import Path
from collections import OrderedDict
from itertools import chain
import json
import os
import sys

env = {
    "V2RAY_CONFIG_PATH": '~/apps/v2ray/config',
    "V2RAY_OUTBOUND_CHAIN": 'dal6',
    "V2RAY_ROUTING_SETUP": 'private-direct,cn-direct'
}
env.update(os.environ)


# %% Initialize
def read_config(config: str):
    try:
        with open(
            Path(env["V2RAY_CONFIG_PATH"])
                .expanduser()
                .joinpath(f'{config}.json'), 'r'
        ) as file:
            return json.load(file, object_pairs_hook=OrderedDict)
    except FileNotFoundError:
        return {}


base = read_config('base')


# %% Outbounds
outbound_chain = env["V2RAY_OUTBOUND_CHAIN"].split('-')
if not outbound_chain:
    sys.exit(1)  # require at least one outbound

outbounds = [
    read_config(f'outbounds/{remote}')
    for remote in reversed(outbound_chain)
]
outbounds = [
    entry
    for entry in outbounds
    if entry
]

## Transit Setup
## ... tag: transitN
## ....... N = 0: dest
## ....... N: distance from dest
if len(outbounds) > 1:
    for idx, transit_dest in enumerate(outbounds[:-1]):
        transit_dest.update(
            {"proxySettings": {"tag": f"transit{idx + 1}"}}
        )
    for idx, transit_via in enumerate(outbounds[:]):
        transit_via.update(
            {"tag": f"transit{idx}"}
        )
outbounds += base['outbounds']


# %% Routing rules
routing_setup = [
    entry.strip()
    for entry in env["V2RAY_ROUTING_SETUP"].split(',')
    if entry.strip()
]
routing_rules = list(chain.from_iterable(  # unpack rules
    read_config(f'routing/{entry}').get('rules', [])
    for entry in routing_setup
))  # can be empty
routing_rules = [
    entry
    for entry in routing_rules
    if entry
]

routing = base['routing']
routing_rules = routing['rules'] + routing_rules
routing.update({'rules': routing_rules})


# %% New config
config = base
config.update({'outbounds': outbounds})
config.update({'routing': routing})
print(json.dumps(config, indent=2))
