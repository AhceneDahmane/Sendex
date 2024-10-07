import folium
import random
from datetime import datetime, timedelta

# Function to generate random GPS data
def generate_random_gps_data(num_points, center_lat, center_lon, lat_range, lon_range):
    data = []
    start_time = datetime.now()

    for _ in range(num_points):
        latitude = round(random.uniform(center_lat - lat_range, center_lat + lat_range), 6)
        longitude = round(random.uniform(center_lon - lon_range, center_lon + lon_range), 6)
        speed = round(random.uniform(0, 3), 2)  # Speed in km/h (0 to 3 km/h)
        timestamp = start_time + timedelta(seconds=_)
        data.append({
            "timestamp": timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            "latitude": latitude,
            "longitude": longitude,
            "speed": speed,
        })

    return data

# Generate random GPS data
num_points = 50  # Number of random points
center_lat = 48.8566  # Center latitude (Paris)
center_lon = 2.3522  # Center longitude (Paris)
lat_range = 0.01  # Latitude range
lon_range = 0.01  # Longitude range

random_data = generate_random_gps_data(num_points, center_lat, center_lon, lat_range, lon_range)

# Create a map centered around the first coordinate
m = folium.Map(location=[random_data[0]['latitude'], random_data[0]['longitude']], zoom_start=15)

# Add markers for each data point
for entry in random_data:
    folium.Marker(
        location=[entry['latitude'], entry['longitude']],
        popup=f"Timestamp: {entry['timestamp']}<br>Speed: {entry['speed']} km/h",
        icon=folium.Icon(color='blue')
    ).add_to(m)

# Create a list of locations for the polyline
locations = [(entry['latitude'], entry['longitude']) for entry in random_data]

# Add a polyline to visualize the path
folium.PolyLine(locations, color='red', weight=2.5, opacity=1).add_to(m)

# Save the map to an HTML file
m.save("random_gps_map.html")

print("Random GPS map has been created and saved as 'random_gps_map.html'.")
