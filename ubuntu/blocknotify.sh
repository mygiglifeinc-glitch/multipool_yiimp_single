#!/usr/bin/env bash
#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################
# Sample blocknotify.sh for a pool with several stratum servers.
blocknotify "stratum_one:$1" "$2" "$3"
blocknotify "stratum_two:$1" "$2" "$3"
blocknotify "stratum_three:$1" "$2" "$3"
