#!/usr/bin/env bash
# desc: herdr stay-awake plugin (holds a sleep inhibitor while agents work)
# os: any
# check: herdr plugin list 2>/dev/null | grep -q 'assawalhy.stay-awake'
# prio: p2
set -euo pipefail
herdr plugin install assawalhy/herdr-stay-awake --yes
