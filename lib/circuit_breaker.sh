#!/bin/bash
# Circuit Breaker for Adversarial Review
# Prevents runaway loops by detecting stagnation or repeated disagreement
# Adapted from asimov-ralph's circuit breaker pattern

# Source date utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/date_utils.sh"

# Circuit Breaker States
CB_STATE_CLOSED="CLOSED"        # Normal operation
CB_STATE_HALF_OPEN="HALF_OPEN"  # Monitoring mode
CB_STATE_OPEN="OPEN"            # Halted

# Configuration (can be overridden)
AR_DIR="${AR_DIR:-.}"
CB_STATE_FILE="$AR_DIR/.circuit_breaker.json"
CB_HISTORY_FILE="$AR_DIR/.circuit_breaker_history.json"

# Thresholds
CB_NO_PROGRESS_THRESHOLD="${CB_NO_PROGRESS_THRESHOLD:-3}"      # Open after N iterations with no fixes
CB_DISAGREEMENT_THRESHOLD="${CB_DISAGREEMENT_THRESHOLD:-5}"    # Open after N iterations of persistent disagreement
CB_SAME_ISSUES_THRESHOLD="${CB_SAME_ISSUES_THRESHOLD:-3}"      # Open after N iterations finding same issues

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Initialize circuit breaker
init_circuit_breaker() {
    mkdir -p "$AR_DIR"

    if [[ -f "$CB_STATE_FILE" ]] && ! jq '.' "$CB_STATE_FILE" > /dev/null 2>&1; then
        rm -f "$CB_STATE_FILE"
    fi

    if [[ ! -f "$CB_STATE_FILE" ]]; then
        cat > "$CB_STATE_FILE" << EOF
{
    "state": "$CB_STATE_CLOSED",
    "last_change": "$(get_iso_timestamp)",
    "consecutive_no_progress": 0,
    "consecutive_disagreement": 0,
    "consecutive_same_issues": 0,
    "last_progress_iteration": 0,
    "total_opens": 0,
    "reason": "",
    "last_issues_hash": ""
}
EOF
    fi

    if [[ ! -f "$CB_HISTORY_FILE" ]]; then
        echo '[]' > "$CB_HISTORY_FILE"
    fi
}

# Get current state
get_circuit_state() {
    if [[ ! -f "$CB_STATE_FILE" ]]; then
        echo "$CB_STATE_CLOSED"
        return
    fi
    jq -r '.state' "$CB_STATE_FILE" 2>/dev/null || echo "$CB_STATE_CLOSED"
}

# Check if execution is allowed
can_execute() {
    local state=$(get_circuit_state)
    [[ "$state" != "$CB_STATE_OPEN" ]]
}

# Record iteration result
# Args: iteration, fixes_made (0/1), agents_agree (0/1), issues_hash
record_iteration_result() {
    local iteration=$1
    local fixes_made=$2
    local agents_agree=$3
    local issues_hash=${4:-""}

    init_circuit_breaker

    local state_data=$(cat "$CB_STATE_FILE")
    local current_state=$(echo "$state_data" | jq -r '.state')
    local no_progress=$(echo "$state_data" | jq -r '.consecutive_no_progress' | tr -d '[:space:]')
    local disagreement=$(echo "$state_data" | jq -r '.consecutive_disagreement' | tr -d '[:space:]')
    local same_issues=$(echo "$state_data" | jq -r '.consecutive_same_issues' | tr -d '[:space:]')
    local last_hash=$(echo "$state_data" | jq -r '.last_issues_hash')
    local last_progress=$(echo "$state_data" | jq -r '.last_progress_iteration' | tr -d '[:space:]')

    # Ensure integers
    no_progress=$((no_progress + 0))
    disagreement=$((disagreement + 0))
    same_issues=$((same_issues + 0))
    last_progress=$((last_progress + 0))

    # Update counters based on results
    if [[ $fixes_made -gt 0 ]]; then
        no_progress=0
        last_progress=$iteration
    else
        no_progress=$((no_progress + 1))
    fi

    if [[ $agents_agree -eq 0 ]]; then
        disagreement=$((disagreement + 1))
    else
        disagreement=0
    fi

    if [[ -n "$issues_hash" ]] && [[ "$issues_hash" == "$last_hash" ]]; then
        same_issues=$((same_issues + 1))
    else
        same_issues=0
    fi

    # Determine new state
    local new_state="$current_state"
    local reason=""

    case $current_state in
        "$CB_STATE_CLOSED")
            if [[ $no_progress -ge $CB_NO_PROGRESS_THRESHOLD ]]; then
                new_state="$CB_STATE_OPEN"
                reason="No progress in $no_progress iterations - agents may be stuck"
            elif [[ $disagreement -ge $CB_DISAGREEMENT_THRESHOLD ]]; then
                new_state="$CB_STATE_OPEN"
                reason="Persistent disagreement for $disagreement iterations"
            elif [[ $same_issues -ge $CB_SAME_ISSUES_THRESHOLD ]]; then
                new_state="$CB_STATE_OPEN"
                reason="Same issues found $same_issues times - unfixable or false positives"
            elif [[ $no_progress -ge 2 || $disagreement -ge 2 ]]; then
                new_state="$CB_STATE_HALF_OPEN"
                reason="Monitoring: possible stagnation"
            fi
            ;;

        "$CB_STATE_HALF_OPEN")
            if [[ $fixes_made -gt 0 ]] && [[ $agents_agree -eq 1 ]]; then
                new_state="$CB_STATE_CLOSED"
                reason="Progress detected, recovered"
            elif [[ $no_progress -ge $CB_NO_PROGRESS_THRESHOLD ]]; then
                new_state="$CB_STATE_OPEN"
                reason="No recovery after monitoring"
            fi
            ;;

        "$CB_STATE_OPEN")
            reason="Circuit open - manual reset required"
            ;;
    esac

    # Update total opens
    local total_opens=$(echo "$state_data" | jq -r '.total_opens' | tr -d '[:space:]')
    total_opens=$((total_opens + 0))
    if [[ "$new_state" == "$CB_STATE_OPEN" && "$current_state" != "$CB_STATE_OPEN" ]]; then
        total_opens=$((total_opens + 1))
    fi

    # Write updated state
    cat > "$CB_STATE_FILE" << EOF
{
    "state": "$new_state",
    "last_change": "$(get_iso_timestamp)",
    "consecutive_no_progress": $no_progress,
    "consecutive_disagreement": $disagreement,
    "consecutive_same_issues": $same_issues,
    "last_progress_iteration": $last_progress,
    "total_opens": $total_opens,
    "reason": "$reason",
    "last_issues_hash": "$issues_hash",
    "current_iteration": $iteration
}
EOF

    # Log transition
    if [[ "$new_state" != "$current_state" ]]; then
        log_circuit_transition "$current_state" "$new_state" "$reason" "$iteration"
    fi

    [[ "$new_state" != "$CB_STATE_OPEN" ]]
}

# Log state transitions
log_circuit_transition() {
    local from=$1
    local to=$2
    local reason=$3
    local iteration=$4

    local history=$(cat "$CB_HISTORY_FILE")
    local entry=$(cat << EOF
{
    "timestamp": "$(get_iso_timestamp)",
    "iteration": $iteration,
    "from": "$from",
    "to": "$to",
    "reason": "$reason"
}
EOF
)

    history=$(echo "$history" | jq ". += [$entry]")
    echo "$history" > "$CB_HISTORY_FILE"

    case $to in
        "$CB_STATE_OPEN")
            echo -e "${RED}[CIRCUIT BREAKER] OPENED${NC}"
            echo -e "${RED}Reason: $reason${NC}"
            ;;
        "$CB_STATE_HALF_OPEN")
            echo -e "${YELLOW}[CIRCUIT BREAKER] Monitoring${NC}"
            echo -e "${YELLOW}Reason: $reason${NC}"
            ;;
        "$CB_STATE_CLOSED")
            echo -e "${GREEN}[CIRCUIT BREAKER] Normal${NC}"
            echo -e "${GREEN}Reason: $reason${NC}"
            ;;
    esac
}

# Show circuit status
show_circuit_status() {
    init_circuit_breaker

    local data=$(cat "$CB_STATE_FILE")
    local state=$(echo "$data" | jq -r '.state')
    local reason=$(echo "$data" | jq -r '.reason')
    local no_progress=$(echo "$data" | jq -r '.consecutive_no_progress')
    local disagreement=$(echo "$data" | jq -r '.consecutive_disagreement')
    local same_issues=$(echo "$data" | jq -r '.consecutive_same_issues')
    local iteration=$(echo "$data" | jq -r '.current_iteration')
    local total_opens=$(echo "$data" | jq -r '.total_opens')

    local color=""
    case $state in
        "$CB_STATE_CLOSED")   color=$GREEN ;;
        "$CB_STATE_HALF_OPEN") color=$YELLOW ;;
        "$CB_STATE_OPEN")      color=$RED ;;
    esac

    echo -e "${color}=== Circuit Breaker Status ===${NC}"
    echo -e "State:              $state"
    echo -e "Reason:             $reason"
    echo -e "No progress:        $no_progress / $CB_NO_PROGRESS_THRESHOLD"
    echo -e "Disagreement:       $disagreement / $CB_DISAGREEMENT_THRESHOLD"
    echo -e "Same issues:        $same_issues / $CB_SAME_ISSUES_THRESHOLD"
    echo -e "Current iteration:  $iteration"
    echo -e "Total opens:        $total_opens"
}

# Reset circuit breaker
reset_circuit_breaker() {
    local reason=${1:-"Manual reset"}
    rm -f "$CB_STATE_FILE" "$CB_HISTORY_FILE"
    init_circuit_breaker
    echo -e "${GREEN}[CIRCUIT BREAKER] Reset to CLOSED${NC}"
}

# Export functions
export -f init_circuit_breaker
export -f get_circuit_state
export -f can_execute
export -f record_iteration_result
export -f show_circuit_status
export -f reset_circuit_breaker
