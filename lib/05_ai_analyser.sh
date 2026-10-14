#!/usr/bin/env bash
# this script carres functions that gets ai response
#
#
#
#

is_online() {   # checks if the computer is online
    ping -c 1 -W 2 1.1.1.1 &>/dev/null
}

