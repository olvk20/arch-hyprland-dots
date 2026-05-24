#!/usr/bin/env bash
# Mode: scan (unpaired only), known (paired only), all (default)
MODE="${1:-all}"

PAIRED_MACS=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}')

RESULTS=()
while read -r _ mac name_rest; do
    [[ -z "$mac" ]] && continue

    is_paired=false
    echo "$PAIRED_MACS" | grep -qx "$mac" && is_paired=true

    case "$MODE" in
        scan)  $is_paired && continue ;;
        known) $is_paired || continue ;;
    esac

    INFO=$(bluetoothctl info "$mac" 2>/dev/null)
    IS_CONN=$(echo "$INFO" | awk '/Connected:/{print $2}')
    BAT=$(echo "$INFO" | grep -i "Battery Percentage" | grep -oP '(?<=\()\d+(?=\))' | head -1)

    if [[ "$IS_CONN" == "yes" ]]; then
        STATUS="●"; CLASS="list-item active"; ICON="󰂱"; CMD="bluetoothctl disconnect"
    else
        STATUS="${BAT:+${BAT}% 󰁹}"
        $is_paired && [[ -z "$STATUS" ]] && STATUS="saved"
        CLASS="list-item"; ICON="󰂯"; CMD="bluetoothctl connect"
    fi

    name_esc="${name_rest//\"/\\\"}"
    RESULTS+=("{\"name\":\"$name_esc\",\"mac\":\"$mac\",\"status\":\"$STATUS\",\"class\":\"$CLASS\",\"icon\":\"$ICON\",\"cmd\":\"$CMD\"}")
done < <(bluetoothctl devices 2>/dev/null | grep "^Device")

echo "[$(IFS=,; echo "${RESULTS[*]}")]"
