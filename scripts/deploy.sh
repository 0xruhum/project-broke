#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

# Deploy.
BrokeAddr=$(deploy Broke 0xaD2F1f7cd663f6a15742675f975CcBD42bb23a88 "[0xBF6201a6c48B56d8577eDD079b84716BB4918E8A,0x2dC36872a445adF0bFf63cc0eeee52A2b801625f,0xC5191A51982983B8105eC4Fbbbf35b9466EE0179,0x6fC99F5591b51583ba15A8C2572408257A1D2797]")
log "Broke deployed at:" $BrokeAddr
