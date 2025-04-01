#!/bin/bash
# filepath: /home/tomas/dev/bash/folowsun/folowsun.sh

# Folowsun - script to switch GNOME theme based on sunrise/sunset
# Automatically switches between light and dark mode

# Default location (Prague, CZ)
DEFAULT_LAT="50.0755"
DEFAULT_LON="14.4378"

# Configuration file
CONFIG_DIR="$HOME/.config/folowsun"
CONFIG_FILE="$CONFIG_DIR/config"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Create default config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOF
# Folowsun configuration
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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$CONFIG_DIR/folowsun.log"
    echo "$1"
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

# Function to get sunrise and sunset times
get_sun_times() {
    # Ensure we have required tools
    if ! command -v curl &>/dev/null; then
        log "Error: curl is required but not installed"
        exit 1
    fi
    
    # Get today's date
    local TODAY=$(date +"%Y-%m-%d")
    
    # Use Sunrise-Sunset.org API to get sun times
    local API_URL="https://api.sunrise-sunset.org/json?lat=$LATITUDE&lng=$LONGITUDE&date=$TODAY&formatted=0"
    
    # Get sun times
    local SUN_DATA=$(curl -s "$API_URL")
    
    # Extract times (in UTC)
    local SUNRISE=$(echo "$SUN_DATA" | grep -o '"sunrise":"[^"]*"' | cut -d'"' -f4)
    local SUNSET=$(echo "$SUN_DATA" | grep -o '"sunset":"[^"]*"' | cut -d'"' -f4)
    
    # Convert to local time and apply offset
    SUNRISE_LOCAL=$(date -d "$SUNRISE $SUNRISE_OFFSET minutes" +"%H:%M")
    SUNSET_LOCAL=$(date -d "$SUNSET $SUNSET_OFFSET minutes" +"%H:%M")
    
    echo "$SUNRISE_LOCAL $SUNSET_LOCAL"
}

# Function to calculate next theme change
schedule_theme_change() {
    local SUN_TIMES=$(get_sun_times)
    local SUNRISE=$(echo "$SUN_TIMES" | cut -d' ' -f1)
    local SUNSET=$(echo "$SUN_TIMES" | cut -d' ' -f2)
    
    local CURRENT_TIME=$(date +"%H:%M")
    
    log "Current time: $CURRENT_TIME, Sunrise: $SUNRISE, Sunset: $SUNSET"
    
    # Determine current expected theme
    if [[ "$CURRENT_TIME" > "$SUNRISE" && "$CURRENT_TIME" < "$SUNSET" ]]; then
        # It's daytime
        set_light_theme
        # Schedule next change at sunset
        local NEXT_CHANGE=$SUNSET
    else
        # It's nighttime
        set_dark_theme
        # Schedule next change at sunrise (possibly tomorrow)
        local NEXT_CHANGE=$SUNRISE
        # If we already passed sunrise today, schedule for tomorrow
        if [[ "$CURRENT_TIME" < "$SUNSET" ]]; then
            # Calculate tomorrow's sunrise
            local TOMORROW=$(date -d "tomorrow" +"%Y-%m-%d")
            local API_URL="https://api.sunrise-sunset.org/json?lat=$LATITUDE&lng=$LONGITUDE&date=$TOMORROW&formatted=0"
            local SUN_DATA=$(curl -s "$API_URL")
            local SUNRISE_TOMORROW=$(echo "$SUN_DATA" | grep -o '"sunrise":"[^"]*"' | cut -d'"' -f4)
            NEXT_CHANGE=$(date -d "$SUNRISE_TOMORROW $SUNRISE_OFFSET minutes" +"%H:%M")
        fi
    fi
    
    log "Next theme change scheduled at $NEXT_CHANGE"
    echo "$NEXT_CHANGE"
}

# Function to show help
show_help() {
    echo "Folowsun - GNOME theme switcher based on sunrise/sunset"
    echo ""
    echo "Usage: folowsun.sh [OPTION]"
    echo ""
    echo "Options:"
    echo "  --help         Show this help"
    echo "  --set-location LAT LON  Set your latitude and longitude"
    echo "  --set-offset SUNRISE_OFFSET SUNSET_OFFSET  Set offsets in minutes"
    echo "  --force-light  Force light theme"
    echo "  --force-dark   Force dark theme"
    echo "  --auto         Apply the appropriate theme based on current time"
    echo "  --daemon       Run as daemon, changing themes at sunrise/sunset"
    echo ""
    echo "Current configuration:"
    echo "  Location: $LATITUDE, $LONGITUDE"
    echo "  Sunrise offset: $SUNRISE_OFFSET minutes"
    echo "  Sunset offset: $SUNSET_OFFSET minutes"
}

# Function to update config file
update_config() {
    cat > "$CONFIG_FILE" << EOF
# Folowsun configuration
LATITUDE=$LATITUDE
LONGITUDE=$LONGITUDE
# Offset in minutes (positive = later, negative = earlier)
SUNRISE_OFFSET=$SUNRISE_OFFSET
SUNSET_OFFSET=$SUNSET_OFFSET
EOF
}

# Parse command line arguments
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
        schedule_theme_change > /dev/null
        ;;
    --daemon)
        log "Starting folowsun daemon"
        while true; do
            # Capture only the time value, not the log messages
            NEXT_CHANGE=$(schedule_theme_change | tail -n 1)
            
            # For debugging
            log "Next change time extracted: $NEXT_CHANGE"
            
            # Calculate seconds until next change
            CURRENT_SECONDS=$(date +%s)
            TARGET_SECONDS=$(date -d "today $NEXT_CHANGE" +%s 2>/dev/null)
            
            # If date command failed or time is in the past, try tomorrow
            if [ $? -ne 0 ] || [ $TARGET_SECONDS -lt $CURRENT_SECONDS ]; then
                TARGET_SECONDS=$(date -d "tomorrow $NEXT_CHANGE" +%s 2>/dev/null)
                if [ $? -ne 0 ]; then
                    # If still failing, use a default wait time
                    log "Error calculating next change time. Waiting for 1 hour."
                    NEXT_CHANGE_SECONDS=3600
                else
                    NEXT_CHANGE_SECONDS=$((TARGET_SECONDS - CURRENT_SECONDS))
                fi
            else
                NEXT_CHANGE_SECONDS=$((TARGET_SECONDS - CURRENT_SECONDS))
            fi
            
            # Make sure we have a positive wait time
            if [ $NEXT_CHANGE_SECONDS -le 0 ]; then
                log "Calculated negative wait time. Defaulting to 1 hour."
                NEXT_CHANGE_SECONDS=3600
            fi
            
            log "Sleeping for $NEXT_CHANGE_SECONDS seconds until next change"
            sleep $NEXT_CHANGE_SECONDS
        done
        ;;
    *)
        show_help
        ;;
esac

exit 0