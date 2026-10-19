import collections
import matplotlib.animation as animation
import matplotlib.pyplot as plt
import numpy as np

DATA_POINTS = 100 # number of data points to display

# use collections.deque to automatically maintain a fixed-length window of data
data_buffer = collections.deque([0.0] * DATA_POINTS, maxlen=DATA_POINTS)

# set up the matplotlib figure and axis
fig, ax = plt.subplots()
(line,) = ax.plot(
    data_buffer, label="Sensor Data"
)  # line object to update dynamically

# configure plot aesthetics
ax.set_title("Serial Input")
ax.set_xlabel("Samples")
ax.set_ylabel("Voltage (mV)")
ax.set_ylim(0, 1023)  # adjust this to match your sensor range (e.g., 0-5V, 0-1023)
ax.grid(True)

# animation update function
def update_plot(frame):
    if not hasattr(update_plot, "val"):
        update_plot.val = 0.0  # initialize static variable
    try:
        # check if there is data waiting in the serial buffer
        if True:
            # read a line, decode binary bytes to string, and strip whitespace/newlines
            raw_data = 250 * np.sin(2 * update_plot.val) + 500 + np.random.normal(0, 5)
            update_plot.val += 0.1

            # convert string data to float/int and append to the buffer
            if raw_data:
                value = float(raw_data)
                data_buffer.append(value)

                # update the y-data of the plot line
                line.set_ydata(data_buffer)
        # calculate stats
        if (frame % 50 == 0):
            print("--- Statistics ---")
            print(f"Mean: {np.mean(data_buffer):.1f} mV")
            print(f"RMS: {np.sqrt(np.mean(np.square(data_buffer))):.1f} mV")
            print(f"Max: {np.max(data_buffer):.1f} mV")
            print(f"Min: {np.min(data_buffer):.1f} mV")
            print(f"Amplitude: {np.max(data_buffer) - np.min(data_buffer):.1f} mV")
            print("\n\n\n\n\n")

    except Exception as e:
        print(f"Error reading serial data: {e}")

    return (line,)

# start the animation
# interval=X -> plot refreshes roughly every Xms
ani = animation.FuncAnimation(
    fig, update_plot, interval=20, blit=True, save_count=DATA_POINTS
)

plt.show()