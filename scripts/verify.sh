#!/bin/bash

set -eo pipefail

# Verify
# https://github.com/dapphub/dapptools/tree/master/src/dapp#dapp-verify-contract
dapp verify-contract src/Broke.sol:Broke $1 0xaD2F1f7cd663f6a15742675f975CcBD42bb23a88 "[0xBF6201a6c48B56d8577eDD079b84716BB4918E8A,0x2dC36872a445adF0bFf63cc0eeee52A2b801625f,0xC5191A51982983B8105eC4Fbbbf35b9466EE0179,0x6fC99F5591b51583ba15A8C2572408257A1D2797]"
