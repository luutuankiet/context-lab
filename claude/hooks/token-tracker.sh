#!/usr/bin/env bash
# Context Lab user-tier token tracker hook.
#
# NOT YET IMPLEMENTED — Phase 1 stub.
#
# The working implementation lives at sandbox-cc:scripts/token-tracker.sh and
# is already fixed and verified in production (session isolation via a
# sanitized .session_id, awk instead of bc, watermark-bounded transcript read).
# It arrives here in the extraction phase; do not re-derive it.
#
# Exits silently so an accidental link cannot break a session.
exit 0
