#!/bin/bash
# followsun - script to switch GNOME theme based on sunrise/sunset
# Automatically switches between light and dark mode

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
        # API failed, try Python script fallback
        log "Warning: Could not fetch sun times from API. Using fallback calculation."

        # Check if Python script exists
        local PYTHON_SCRIPT="$SCRIPT_DIR/sun_calculator.py"
        if [[ -f "$PYTHON_SCRIPT" && -x "$PYTHON_SCRIPT" ]]; then
            # Call the Python script
            if command -v python3 &>/dev/null; then
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
            log "Fallback script not found. Checking for cached values."
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
            local MONTH=$(date +%m)
            # Seasonal defaults
            if [[ "$MONTH" -ge 4 && "$MONTH" -le 9 ]]; then
                # Spring/Summer
                SUNRISE_LOCAL="05:30"
                SUNSET_LOCAL="20:30"
            else
                # Fall/Winter
                SUNRISE_LOCAL="07:00"
                SUNSET_LOCAL="16:30"
            fi
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
    echo "  --install-fallback Install Python fallback calculator"
    echo "  --debug        Run with verbose debugging output"
    echo ""
    echo "Current configuration:"
    echo "  Location: $LATITUDE, $LONGITUDE"
    echo "  Sunrise offset: $SUNRISE_OFFSET minutes"
    echo "  Sunset offset: $SUNSET_OFFSET minutes"
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

# Function to install Python fallback script
install_fallback() {
    local PYTHON_SCRIPT="$SCRIPT_DIR/sun_calculator.py"

    # Check if Python 3 is installed
    if ! command -v python3 &>/dev/null; then
        log "Error: Python 3 is required for the fallback calculator but not installed"
        exit 1
    fi

    # Create the Python script
    cat >"$PYTHON_SCRIPT" <<"EOF"
#!/usr/bin/env python3
"""
Sun Calculator - Calculate sunrise and sunset times for a given location
Used by followsun.sh when internet connection is unavailable
"""

import sys
import datetime
import traceback

# Try to import astral, handle missing dependency gracefully
try:
    from astral import LocationInfo
    from astral.sun import sun
    ASTRAL_AVAILABLE = True
except ImportError:
    ASTRAL_AVAILABLE = False

def calculate_sun_times_astral(latitude, longitude, sunrise_offset=0, sunset_offset=0):
    """Calculate sunrise and sunset times using astral library."""
    # Get current date and timezone
    today = datetime.datetime.now()
    timezone = datetime.datetime.now().astimezone().tzinfo
    
    # Create location info
    location = LocationInfo(
        name="CustomLocation",
        region="CustomRegion",
        timezone=str(timezone),
        latitude=float(latitude),
        longitude=float(longitude)
    )
    
    # Get sun information for today
    s = sun(location.observer, date=today, tzinfo=timezone)
    
    # Extract sunrise and sunset times
    sunrise = s["sunrise"]
    sunset = s["sunset"]
    
    # Apply offsets
    sunrise = sunrise + datetime.timedelta(minutes=int(sunrise_offset))
    sunset = sunset + datetime.timedelta(minutes=int(sunset_offset))
    
    # Format times as HH:MM
    sunrise_time = sunrise.strftime("%H:%M")
    sunset_time = sunset.strftime("%H:%M")
    
    return sunrise_time, sunset_time

def calculate_sun_times_fallback(latitude, longitude, sunrise_offset=0, sunset_offset=0):
    """Fallback calculation method if astral is not available."""
    import math
    
    # Convert latitude and longitude to radians
    lat_rad = math.radians(float(latitude))
    
    # Get current date
    today = datetime.datetime.now()
    day_of_year = today.timetuple().tm_yday
    
    # Calculate solar declination (radians)
    # Approximation from NOAA calculations
    declination = 0.409 * math.sin(2 * math.pi / 365 * (day_of_year - 80))
    
    # Calculate day length (from sunrise to sunset) in hours
    day_length = 24 - (24 / math.pi) * math.acos(
        (math.sin(math.radians(-0.83)) + math.sin(lat_rad) * math.sin(declination)) /
        (math.cos(lat_rad) * math.cos(declination))
    )
    
    # Calculate noon offset due to longitude and time zone
    tz_offset = datetime.datetime.now().astimezone().utcoffset().total_seconds() / 3600
    longitude_correction = float(longitude) / 15 - tz_offset
    
    # Calculate approximate solar noon
    solar_noon = 12 - longitude_correction
    
    # Calculate sunrise and sunset
    sunrise = solar_noon - day_length / 2
    sunset = solar_noon + day_length / 2
    
    # Apply offsets
    sunrise += int(sunrise_offset) / 60
    sunset += int(sunset_offset) / 60
    
    # Handle edge cases - truncate day_length to reasonable values
    if not (4 <= day_length <= 20):
        # Polar day/night or calculation error
        # Use reasonable defaults based on season for central Europe
        if 80 <= day_of_year <= 265:  # Spring and summer
            sunrise, sunset = 5.5, 21.0
        else:  # Fall and winter
            sunrise, sunset = 7.0, 18.0
    
    # Format times
    def format_time(hours):
        # Handle hours wrap around
        while hours < 0:
            hours += 24
        while hours >= 24:
            hours -= 24
        
        # Convert decimal hours to hours:minutes format
        h = int(hours)
        m = int((hours - h) * 60)
        return f"{h:02d}:{m:02d}"
    
    sunrise_time = format_time(sunrise)
    sunset_time = format_time(sunset)
    
    return sunrise_time, sunset_time

def calculate_sun_times(latitude, longitude, sunrise_offset=0, sunset_offset=0):
    """Calculate sunrise and sunset times for the given location and date."""
    try:
        # Try to use astral if available
        if ASTRAL_AVAILABLE:
            return calculate_sun_times_astral(latitude, longitude, sunrise_offset, sunset_offset)
        else:
            # Print a notice about astral being unavailable
            print("NOTICE: Using fallback calculation (astral not installed)", file=sys.stderr)
            print("For better accuracy install astral: pip install astral", file=sys.stderr)
            return calculate_sun_times_fallback(latitude, longitude, sunrise_offset, sunset_offset)
    except Exception as e:
        # If any calculation fails, use fallback
        print(f"ERROR: {str(e)}", file=sys.stderr)
        print(traceback.format_exc(), file=sys.stderr)
        print("NOTICE: Calculation error, using seasonal defaults", file=sys.stderr)
        
        # Use seasonal defaults based on current month
        month = datetime.datetime.now().month
        if 3 <= month <= 10:  # Spring and summer
            return "06:30", "20:00"
        else:  # Fall and winter
            return "07:30", "16:30"

if __name__ == "__main__":
    # Check arguments
    if len(sys.argv) < 3:
        print("Usage: sun_calculator.py LATITUDE LONGITUDE [SUNRISE_OFFSET SUNSET_OFFSET]")
        sys.exit(1)
    
    # Parse arguments
    latitude = sys.argv[1]
    longitude = sys.argv[2]
    sunrise_offset = sys.argv[3] if len(sys.argv) > 3 else 0
    sunset_offset = sys.argv[4] if len(sys.argv) > 4 else 0
    
    # Calculate and output
    source = "ASTRAL" if ASTRAL_AVAILABLE else "CALCULATED"
    try:
        sunrise, sunset = calculate_sun_times(latitude, longitude, sunrise_offset, sunset_offset)
        print(f"{source} {sunrise} {sunset}")
    except Exception as e:
        print(f"ERROR: {str(e)}", file=sys.stderr)
        print("DEFAULT 06:30 19:30")
EOF

    # Make the script executable
    chmod +x "$PYTHON_SCRIPT"
    log "Python fallback calculator installed to $PYTHON_SCRIPT"

    # Try to install the astral package
    if command -v pip3 &>/dev/null; then
        log "Installing astral package..."
        if pip3 install --user astral; then
            log "Astral package installed successfully"
        else
            log "Warning: Failed to install astral package. Basic calculations will be used instead."
        fi
    else
        log "Warning: pip3 not found. Cannot install astral package automatically. For better accuracy, install it manually: pip3 install astral"
    fi

    # Test the script
    if "$PYTHON_SCRIPT" "$LATITUDE" "$LONGITUDE" "$SUNRISE_OFFSET" "$SUNSET_OFFSET"; then
        log "Fallback calculator test successful"
    else
        log "Warning: Fallback calculator test failed"
    fi
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
--install-fallback)
    install_fallback
    ;;
*)
    show_help
    ;;
esac

exit 0
