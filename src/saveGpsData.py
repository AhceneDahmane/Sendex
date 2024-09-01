import serial
import time
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation

# Replace 'COM3' with your Arduino's serial port name
ser = serial.Serial('COM3', 9600, timeout=1)
time.sleep(2)  # Wait for the serial connection to initialize

# Initialize lists to hold the data
times = []
distances = []
speeds = []
latitudes = []
longitudes = []

start_time = time.time()

# Set up the plot
fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(10, 15))
fig.suptitle("Real-Time GPS Data")

def update_plot(frame):
    line = ser.readline().decode('utf-8').strip()
    
    if line:
        print(line)  # Print the line for debugging
        
        # Assuming your serial output is structured as:
        # Latitude, Longitude, Date, Time, Speed (km/h), Distance (m), Total Distance (m)
        data = line.split(', ')
        
        if len(data) >= 7:
            lat = float(data[0])
            lng = float(data[1])
            speed = float(data[4])
            distance = float(data[6])
            
            current_time = time.time() - start_time
            
            latitudes.append(lat)
            longitudes.append(lng)
            speeds.append(speed)
            distances.append(distance)
            times.append(current_time)
            
            # Clear the previous plots
            ax1.clear()
            ax2.clear()
            ax3.clear()
            
            # Plot Distance over Time
            ax1.plot(times, distances, 'b-')
            ax1.set_xlabel("Time (s)")
            ax1.set_ylabel("Total Distance (m)")
            ax1.set_title("Total Distance Over Time")
            
            # Plot Speed over Time
            ax2.plot(times, speeds, 'g-')
            ax2.set_xlabel("Time (s)")
            ax2.set_ylabel("Speed (km/h)")
            ax2.set_title("Speed Over Time")
            
            # Plot Position over Time (Latitude and Longitude)
            ax3.plot(times, latitudes, 'r-', label="Latitude")
            ax3.plot(times, longitudes, 'm-', label="Longitude")
            ax3.set_xlabel("Time (s)")
            ax3.set_ylabel("Position")
            ax3.set_title("Position (Latitude and Longitude) Over Time")
            ax3.legend()
            
            plt.tight_layout(rect=[0, 0, 1, 0.96])  # Adjust the layout to fit the title
            
    return ax1, ax2, ax3

# Create an animation that updates the plot in real-time
ani = FuncAnimation(fig, update_plot, interval=1000)

# To save the plot as a png file when the plot window is closed
def save_plot_on_close(event):
    plt.savefig("gps_data_plot.png")
    ser.close()
    print("Plot saved as gps_data_plot.png")

fig.canvas.mpl_connect('close_event', save_plot_on_close)

# Start the real-time plot
plt.show()
