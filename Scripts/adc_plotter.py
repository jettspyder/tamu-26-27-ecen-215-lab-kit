import collections
import matplotlib.animation as animation
import matplotlib.pyplot as plt
import serial

# serial port configuration
SERIAL_PORT = "/dev/ttyACM0" # exact path may vary
BAUD_RATE = 115200 # symbols/s
DATA_POINTS = 100 # number of data points to display

# open serial connection
ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)

# use collections.deque to automatically maintain a fixed-length window of data
data_buffer = collections.deque([0.0] * DATA_POINTS, maxlen=DATA_POINTS)

# set up the matplotlib figure and axis
fig, ax = plt.subplots()
(line,) = ax.plot(
    data_buffer, label="Sensor Data"
)  # line object to update dynamically

# configure plot aesthetics
ax.set_title("Real-Time Serial Data Plot")
ax.set_xlabel("Samples")
ax.set_ylabel("Value")
ax.set_ylim(0, 1023)  # adjust this to match your sensor range (e.g., 0-5V, 0-1023)
ax.grid(True)


# animation update function
def update_plot(frame):
    try:
        # check if there is data waiting in the serial buffer
        if ser.in_waiting > 0:
            # read a line, decode binary bytes to string, and strip whitespace/newlines
            raw_data = ser.readline().decode("utf-8").strip()

            # convert string data to float/int and append to the buffer
            if raw_data:
                value = float(raw_data)
                data_buffer.append(value)

                # update the y-data of the plot line
                line.set_ydata(data_buffer)

    except Exception as e:
        print(f"Error reading serial data: {e}")

    return (line,)


# start the animation
# interval=X -> plot refreshes roughly every Xms
ani = animation.FuncAnimation(
    fig, update_plot, interval=20, blit=True, save_count=DATA_POINTS
)

try:
    plt.show()
finally:
    # ensure the serial port safely closes when the window is exited
    ser.close()
    print("Serial port closed.")