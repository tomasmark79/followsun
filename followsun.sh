#!/bin/bash
# followsun - script to switch GNOME theme based on sunrise/sunset
# Automatically switches between light and dark mode

# MIT License
# Copyright (c) 2025 Tomáš Mark

# Default location (Prague, CZ)
DEFAULT_LAT="50.0755"
DEFAULT_LON="14.4378"

# Configuration file
CONFIG_DIR="$HOME/.config/followsun"
CONFIG_FILE="$CONFIG_DIR/config"

# Script directory
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Create default config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    cat >"$CONFIG_FILE" <<EOF
# followsun configuration
LATITUDE=$DEFAULT_LAT
LONGITUDE=$DEFAULT_LON
# Offset in minutes (positive = later, negative = earlier)
SUNRISE_OFFSET=0
SUNSET_OFFSET=0
EOF
fi

# Source the config file
source "$CONFIG_FILE"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >>"$CONFIG_DIR/followsun.log"
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "[DEBUG] $1"
    else
        echo "$1"
    fi
}

# Function to set light theme
set_light_theme() {
    gsettings set org.gnome.desktop.interface color-scheme 'default'
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
    log "Switched to light theme"
}

# Function to set dark theme
set_dark_theme() {
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    log "Switched to dark theme"
}

# Function to calculate seasonal default sunrise/sunset times
get_seasonal_defaults() {
    local MONTH=$(date +%m)
    # Seasonal defaults
    if [[ "$MONTH" -ge 4 && "$MONTH" -le 9 ]]; then
        # Spring/Summer
        echo "05:30 20:30"
    else
        # Fall/Winter
        echo "07:00 16:30"
    fi
}

# Function to get sunrise and sunset times
get_sun_times() {
    # Ensure we have required tools
    if ! command -v curl &>/dev/null; then
        log "Error: curl is required but not installed"
        exit 1
    fi

    # Get today's date
    local TODAY=$(date +"%Y-%m-%d")

    # Try to get sun times from API first
    local API_URL="https://api.sunrise-sunset.org/json?lat=$LATITUDE&lng=$LONGITUDE&date=$TODAY&formatted=0"
    local SUN_DATA=$(curl -s --connect-timeout 5 "$API_URL")

    # Check if API call was successful
    if [[ "$SUN_DATA" == *"\"status\":\"OK\""* ]]; then
        # Extract times (in UTC)
        local SUNRISE=$(echo "$SUN_DATA" | grep -o '"sunrise":"[^"]*"' | cut -d'"' -f4)
        local SUNSET=$(echo "$SUN_DATA" | grep -o '"sunset":"[^"]*"' | cut -d'"' -f4)

        # Convert to local time and apply offset
        SUNRISE_LOCAL=$(date -d "$SUNRISE $SUNRISE_OFFSET minutes" +"%H:%M")
        SUNSET_LOCAL=$(date -d "$SUNSET $SUNSET_OFFSET minutes" +"%H:%M")

        # Save to cache
        echo "$SUNRISE_LOCAL $SUNSET_LOCAL $TODAY" >"$CONFIG_DIR/sun_cache"
        log "Sun times from API: Sunrise: $SUNRISE_LOCAL, Sunset: $SUNSET_LOCAL"
    else
        # API failed, check for external fallback calculator
        log "Warning: Could not fetch sun times from API. Checking for fallback options."

        # Check if external calculator exists
        local PYTHON_SCRIPT="$SCRIPT_DIR/sun_calculator.py"
        if [[ -f "$PYTHON_SCRIPT" && -x "$PYTHON_SCRIPT" ]]; then
            # Call the external calculator
            if command -v python3 &>/dev/null; then
                log "Using external Python calculator"
                local FALLBACK_RESULT=$("$PYTHON_SCRIPT" "$LATITUDE" "$LONGITUDE" "$SUNRISE_OFFSET" "$SUNSET_OFFSET")
                local SOURCE=$(echo "$FALLBACK_RESULT" | cut -d' ' -f1)
                SUNRISE_LOCAL=$(echo "$FALLBACK_RESULT" | cut -d' ' -f2)
                SUNSET_LOCAL=$(echo "$FALLBACK_RESULT" | cut -d' ' -f3)

                log "Using $SOURCE sun times: Sunrise: $SUNRISE_LOCAL, Sunset: $SUNSET_LOCAL"

                # Save to cache
                echo "$SUNRISE_LOCAL $SUNSET_LOCAL $TODAY" >"$CONFIG_DIR/sun_cache"
            else
                log "Python 3 not found. Checking for cached values."
            fi
        else
            log "External calculator not found. Checking for cached values."
        fi

        # If we don't have values yet, try the cache
        if [[ -z "$SUNRISE_LOCAL" || -z "$SUNSET_LOCAL" ]]; then
            if [[ -f "$CONFIG_DIR/sun_cache" ]]; then
                local CACHE_DATE=$(awk '{print $3}' "$CONFIG_DIR/sun_cache" 2>/dev/null)
                # Only use cache if it's from today or yesterday
                if [[ "$CACHE_DATE" == "$TODAY" || "$CACHE_DATE" == "$(date -d 'yesterday' +%Y-%m-%d)" ]]; then
                    SUNRISE_LOCAL=$(awk '{print $1}' "$CONFIG_DIR/sun_cache" 2>/dev/null)
                    SUNSET_LOCAL=$(awk '{print $2}' "$CONFIG_DIR/sun_cache" 2>/dev/null)
                    log "Using cached sun times: Sunrise: $SUNRISE_LOCAL, Sunset: $SUNSET_LOCAL"
                fi
            fi
        fi

        # If we still don't have values, use reasonable defaults for central Europe
        if [[ -z "$SUNRISE_LOCAL" || -z "$SUNSET_LOCAL" ]]; then
            local DEFAULTS=$(get_seasonal_defaults)
            SUNRISE_LOCAL=$(echo "$DEFAULTS" | cut -d' ' -f1)
            SUNSET_LOCAL=$(echo "$DEFAULTS" | cut -d' ' -f2)
            log "Using default seasonal sun times: Sunrise: $SUNRISE_LOCAL, Sunset: $SUNSET_LOCAL"
        fi
    fi

    # Clean up and normalize output format
    SUNRISE_LOCAL=$(echo "$SUNRISE_LOCAL" | tr -d '\n')
    SUNSET_LOCAL=$(echo "$SUNSET_LOCAL" | tr -d '\n')

    echo "$SUNRISE_LOCAL $SUNSET_LOCAL"
}

# Function to calculate next theme change
schedule_theme_change() {
    local SUN_TIMES=$(get_sun_times)
    
    # More thorough cleanup of the times
    local SUNRISE=$(echo "$SUN_TIMES" | cut -d' ' -f1 | tr -d '\n' | tr -d '\r' | sed 's/\[DEBUG\]//g')
    local SUNSET=$(echo "$SUN_TIMES" | cut -d' ' -f2 | tr -d '\n' | tr -d '\r' | sed 's/Sun//g')

    local CURRENT_TIME=$(date +"%H:%M")

    log "Current time: $CURRENT_TIME, Sunrise: $SUNRISE, Sunset: $SUNSET"

    # Extract hours and minutes with safer parsing
    local CT_HOUR=$(echo "$CURRENT_TIME" | cut -d':' -f1)
    local CT_MIN=$(echo "$CURRENT_TIME" | cut -d':' -f2)
    local SR_HOUR=$(echo "$SUNRISE" | cut -d':' -f1)
    local SR_MIN=$(echo "$SUNRISE" | cut -d':' -f2)
    local SS_HOUR=$(echo "$SUNSET" | cut -d':' -f1)
    local SS_MIN=$(echo "$SUNSET" | cut -d':' -f2)
    
    # Ensure we're working with clean numbers and remove leading zeros
    CT_HOUR=$(echo "$CT_HOUR" | sed 's/[^0-9]//g' | sed 's/^0*//')
    CT_MIN=$(echo "$CT_MIN" | sed 's/[^0-9]//g' | sed 's/^0*//')
    SR_HOUR=$(echo "$SR_HOUR" | sed 's/[^0-9]//g' | sed 's/^0*//')
    SR_MIN=$(echo "$SR_MIN" | sed 's/[^0-9]//g' | sed 's/^0*//')
    SS_HOUR=$(echo "$SS_HOUR" | sed 's/[^0-9]//g' | sed 's/^0*//')
    SS_MIN=$(echo "$SS_MIN" | sed 's/[^0-9]//g' | sed 's/^0*//')
    
    # Default to 0 if empty (for example, if hours is "00")
    CT_HOUR=${CT_HOUR:-0}
    CT_MIN=${CT_MIN:-0}
    SR_HOUR=${SR_HOUR:-0}
    SR_MIN=${SR_MIN:-0}
    SS_HOUR=${SS_HOUR:-0}
    SS_MIN=${SS_MIN:-0}
    
    # Convert to minutes since midnight with safer arithmetic
    local CT_MINUTES=$((CT_HOUR * 60 + CT_MIN))
    local SR_MINUTES=$((SR_HOUR * 60 + SR_MIN))
    local SS_MINUTES=$((SS_HOUR * 60 + SS_MIN))

    log "Time in minutes - Current: $CT_MINUTES, Sunrise: $SR_MINUTES, Sunset: $SS_MINUTES"

    # Determine current expected theme using numeric comparison
    if [[ $CT_MINUTES -ge $SR_MINUTES && $CT_MINUTES -lt $SS_MINUTES ]]; then
        # It's daytime
        log "Time comparison: ($CT_MINUTES >= $SR_MINUTES) && ($CT_MINUTES < $SS_MINUTES) = true (daytime)"
        set_light_theme
        # Schedule next change at sunset
        local NEXT_CHANGE=$SUNSET
    else
        # It's nighttime
        log "Time comparison: ($CT_MINUTES >= $SR_MINUTES) && ($CT_MINUTES < $SS_MINUTES) = false (nighttime)"
        if [[ $CT_MINUTES -lt $SR_MINUTES ]]; then
            log "Time is before sunrise"
        elif [[ $CT_MINUTES -ge $SS_MINUTES ]]; then
            log "Time is after sunset"
        else
            log "Unexpected condition in time comparison"
        fi

        set_dark_theme
        # Schedule next change at sunrise (possibly tomorrow)
        local NEXT_CHANGE=$SUNRISE
        # If we already passed sunrise today, schedule for tomorrow
        if [[ $CT_MINUTES -lt $SS_MINUTES ]]; then
            # Try API first for tomorrow's sunrise
            local TOMORROW=$(date -d "tomorrow" +"%Y-%m-%d")
            local API_URL="https://api.sunrise-sunset.org/json?lat=$LATITUDE&lng=$LONGITUDE&date=$TOMORROW&formatted=0"
            local SUN_DATA=$(curl -s --connect-timeout 5 "$API_URL")

            if [[ "$SUN_DATA" == *"\"status\":\"OK\""* ]]; then
                local SUNRISE_TOMORROW=$(echo "$SUN_DATA" | grep -o '"sunrise":"[^"]*"' | cut -d'"' -f4)
                NEXT_CHANGE=$(date -d "$SUNRISE_TOMORROW $SUNRISE_OFFSET minutes" +"%H:%M")
            else
                # API failed, just add 24 hours to today's sunrise as an estimate
                NEXT_CHANGE=$(date -d "$SUNRISE 24 hours" +"%H:%M")
            fi
        fi
    fi

    log "Next theme change scheduled at $NEXT_CHANGE"
    echo "$NEXT_CHANGE"
}

# Function to show help
show_help() {
    echo "FollowSun - GNOME theme switcher based on sunrise/sunset"
    echo ""
    echo "Usage: followsun.sh [OPTION]"
    echo ""
    echo "Options:"
    echo "  --help         Show this help"
    echo "  --set-location <LAT> <LON> Set your latitude and longitude"
    echo "  --set-offset   <SUNRISE_OFFSET> <SUNSET_OFFSET> Set offsets in minutes"
    echo "  --force-light  Force light theme"
    echo "  --force-dark   Force dark theme"
    echo "  --auto         Apply the appropriate theme based on current time"
    echo "  --debug        Run with verbose debugging output"
    echo ""
    echo "Current configuration:"
    echo "  Location: $LATITUDE, $LONGITUDE"
    echo "  Sunrise offset: $SUNRISE_OFFSET minutes"
    echo "  Sunset offset: $SUNSET_OFFSET minutes"
    echo ""
    echo "Note: For offline sun calculation, place a sun_calculator.py script in the same"
    echo "      directory as this script. It should accept latitude, longitude, and offsets"
    echo "      as parameters and output 'SOURCE HH:MM HH:MM' for sunrise and sunset."
}

# Function to update config file
update_config() {
    cat >"$CONFIG_FILE" <<EOF
# followsun configuration
LATITUDE=$LATITUDE
LONGITUDE=$LONGITUDE
# Offset in minutes (positive = later, negative = earlier)
SUNRISE_OFFSET=$SUNRISE_OFFSET
SUNSET_OFFSET=$SUNSET_OFFSET
EOF
}

# Parse command line arguments
DEBUG_MODE="false"
case "$1" in
--help)
    show_help
    ;;
--set-location)
    if [ -n "$2" ] && [ -n "$3" ]; then
        LATITUDE="$2"
        LONGITUDE="$3"
        update_config
        log "Location updated to $LATITUDE, $LONGITUDE"
    else
        echo "Error: Latitude and longitude required"
        exit 1
    fi
    ;;
--set-offset)
    if [ -n "$2" ] && [ -n "$3" ]; then
        SUNRISE_OFFSET="$2"
        SUNSET_OFFSET="$3"
        update_config
        log "Offsets updated to sunrise: $SUNRISE_OFFSET, sunset: $SUNSET_OFFSET"
    else
        echo "Error: Sunrise and sunset offsets required"
        exit 1
    fi
    ;;
--force-light)
    set_light_theme
    ;;
--force-dark)
    set_dark_theme
    ;;
--auto)
    schedule_theme_change >/dev/null
    ;;
--debug)
    DEBUG_MODE="true"
    echo "[DEBUG] Debug mode enabled"
    schedule_theme_change
    ;;
*)
    show_help
    ;;
esac

exit 0