#!/usr/bin/env bash
# scripts/host-drivers/github.sh — GitHub driver.
# Uses `gh` CLI for creation and authentication, GitHub REST API for protection.
# Implements the solo-orchestrator host driver contract defined in spec
# docs/superpowers/specs/2026-04-21-host-aware-repo-gate-design.md.

host_name() { echo "github"; }
