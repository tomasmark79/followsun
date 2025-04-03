#!/usr/bin/env python3
"""
Sun Calculator - Calculate sunrise and sunset times for a given location
Used by followsun.sh when internet connection is unavailable
"""

import sys
import datetime
from zoneinfo import ZoneInfo
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