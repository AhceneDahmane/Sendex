import numpy as np
import matplotlib.pyplot as plt
import time
# Simulated GPS data (longitude, latitude, altitude, timestamp)
gps_data = [
    (-73.985410, 40.748820, 15.0, "12:00:01"), 
    (-73.985420, 40.748830, 15.1, "12:00:02"), 
    (-73.985430, 40.748840, 15.2, "12:00:03"), 
    (-73.985440, 40.748850, 15.3, "12:00:04"), 
    (-73.985450, 40.748860, 15.2, "12:00:05"),
    (-73.985460, 40.748870, 15.0, "12:00:06"),
    (-73.985470, 40.748880, 15.0, "12:00:07"),
    (-73.985490, 40.748900, 14.9, "12:00:08"),
    (-73.985480, 40.748930, 14.8, "12:00:09"),
    (-73.985500, 40.748940, 14.7, "12:00:10"),
    (-73.985520, 40.748950, 14.7, "12:00:11"),
    (-73.985530, 40.748960, 14.6, "12:00:12"),
    (-73.985540, 40.748970, 14.5, "12:00:13"),
    (-73.985550, 40.748980, 14.5, "12:00:14"),
    (-73.985560, 40.748990, 14.4, "12:00:15"),
    (-73.985570, 40.749000, 14.3, "12:00:16"),
    (-73.985580, 40.749010, 14.3, "12:00:17"),
    (-73.985590, 40.749020, 14.2, "12:00:18"),
    (-73.985600, 40.749030, 14.2, "12:00:19"),
    (-73.985610, 40.749040, 14.1, "12:00:20"),
    (-73.985620, 40.749050, 14.1, "12:00:21")
    # Add more data as needed
]

# Define pitch boundaries (GPS coordinates of the four corners of the pitch)
lat_min, lat_max = 40.748500, 40.749200  # Adjusted latitude boundaries
lon_min, lon_max = -73.985700, -73.985200  # Adjusted longitude boundaries

# Pitch image dimensions (in pixels)
img_width = 1050  # proportional to the pitch length
img_height = 680  # proportional to the pitch width

# Load the football pitch image
pitch_image_path = '/content/pitch_football.jpg' 
pitch_image = plt.imread(pitch_image_path)

# Function to map GPS coordinates to pitch image coordinates
def gps_to_pitch(lat, lon, lat_min, lat_max, lon_min, lon_max, img_width, img_height):
    x = (lon - lon_min) * img_width / (lon_max - lon_min)
    y = (lat - lat_min) * img_height / (lat_max - lat_min)
    return int(x), img_height - int(y)  # Invert y to match image coordinates

# List to store pitch coordinates for plotting
pitch_positions = []

# Real-time simulation (just printing data)
for lon, lat, alt, timestamp in gps_data:
    x, y = gps_to_pitch(lat, lon, lat_min, lat_max, lon_min, lon_max, img_width, img_height)
    
    # Print current position, altitude, and time
    print(f"Time: {timestamp} | Position on the pitch: (x={x}, y={y}) | Altitude: {alt} meters")
    
    # Simulate real-time delay (e.g., GPS data received every second)
    time.sleep(1)
    
    # Store the current pitch coordinates for later plotting
    pitch_positions.append((x, y))

# Plot all positions on the pitch after processing all data
plt.figure(figsize=(10.5, 6.8))
plt.imshow(pitch_image, extent=[0, img_width, 0, img_height])  # Display pitch image

# Plot all positions
x_vals, y_vals = zip(*pitch_positions)
plt.scatter(x_vals, y_vals, color='red', s=100)  # Plot all positions

plt.title('Final Positions on the Pitch')
plt.axis('off')  # Turn off axes
plt.show()
