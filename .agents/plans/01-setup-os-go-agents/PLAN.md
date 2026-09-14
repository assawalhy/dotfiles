# Plan: setup-os Go section & coding agents

## Goal
Improve `setup-os` to support `go install` as a package manager (like cargo/pip),
adjust priority tiers for go and glow, and add coding agents (pi, claude, codex,
opencode, kilo) to the packages list.

## Changes
1. **packages.list**: Move `go` step from p1 to p2, keep glow at p2
2. **packages.list**: Add coding agents to `[go]` or appropriate sections
3. **setup-os**: Already has `[go]` section support from prior work
4. **05-golang.sh**: Already created for Go auto-install
