#!/bin/bash
# Date Utilities for Adversarial Review
# Cross-platform date handling

# Get ISO 8601 timestamp
get_iso_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get epoch seconds (cross-platform)
get_epoch_seconds() {
    if date +%s &>/dev/null; then
        date +%s
    else
        # Fallback for systems without %s support
        python3 -c "import time; print(int(time.time()))" 2>/dev/null || echo "0"
    fi
}

# Get human-readable duration from seconds
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

# Export functions
export -f get_iso_timestamp
export -f get_epoch_seconds
export -f format_duration
