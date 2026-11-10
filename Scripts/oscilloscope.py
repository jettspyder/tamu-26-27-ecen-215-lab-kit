
import csv
import queue
import threading
from collections import deque

import numpy as np
import serial
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from matplotlib.widgets import Button, Slider, CheckButtons

PORT = "/dev/ttyACM0"
BAUD = 115200

MAX_SAMPLES = 10000
ADC_FULL_SCALE_MV = 1800.0
ADC_COUNTS = 4096.0

samples = queue.Queue()
running = True
paused = False
recording = False

times = deque(maxlen=MAX_SAMPLES)
ch0_data = deque(maxlen=MAX_SAMPLES)
ch1_data = deque(maxlen=MAX_SAMPLES)

ser = serial.Serial(PORT, BAUD, timeout=0.2)

csv_file = None
csv_writer = None


def read_serial():
    global running

    while running:
        try:
            line = ser.readline().decode(
                "utf-8", errors="ignore"
            ).strip()

            if not line or line.startswith("#"):
                continue

            parts = line.split(",")

            if len(parts) != 3:
                continue

            t, raw0, raw1 = map(int, parts)

            # Nominal single-ended voltage conversion
            v0 = max(0, raw0) * ADC_FULL_SCALE_MV / ADC_COUNTS
            v1 = max(0, raw1) * ADC_FULL_SCALE_MV / ADC_COUNTS

            samples.put((t / 1000.0, v0 / 1000.0,
                         v1 / 1000.0))

        except (ValueError, UnicodeError):
            continue
        except serial.SerialException as e:
            print("Serial error:", e)
            running = False
            break


thread = threading.Thread(target=read_serial, daemon=True)
thread.start()

fig, ax = plt.subplots(figsize=(11, 6))
plt.subplots_adjust(bottom=0.32)

line0, = ax.plot([], [], label="CH1 - AIN0",
                 color="dodgerblue")
line1, = ax.plot([], [], label="CH2 - AIN1",
                 color="orange")

ax.set_title("nRF52 Two-Channel Oscilloscope")
ax.set_xlabel("Time (s)")
ax.set_ylabel("Voltage (V)")
ax.set_ylim(0, 3.3)
ax.grid(True)
ax.legend(loc="upper right")

# Timebase slider
time_ax = plt.axes((0.20, 0.20, 0.65, 0.03))
time_slider = Slider(
    time_ax, "Window (s)", 0.1, 10.0,
    valinit=2.0
)

# Vertical range slider
volt_ax = plt.axes((0.20, 0.15, 0.65, 0.03))
volt_slider = Slider(
    volt_ax, "Max V", 0.5, 3.6,
    valinit=3.3
)

# Trigger level
trigger_ax = plt.axes((0.20, 0.10, 0.65, 0.03))
trigger_slider = Slider(
    trigger_ax, "Trigger V", 0.0, 3.3,
    valinit=1.5
)

# Buttons
pause_ax = plt.axes((0.18, 0.025, 0.16, 0.05))
record_ax = plt.axes((0.40, 0.025, 0.16, 0.05))
trigger_check_ax = plt.axes((0.68, 0.015, 0.20, 0.065))

pause_button = Button(pause_ax, "Pause")
record_button = Button(record_ax, "Record")
trigger_check = CheckButtons(
    trigger_check_ax, ["Trigger CH1"], [False]
)


def toggle_pause(event):
    global paused
    paused = not paused
    pause_button.label.set_text(
        "Resume" if paused else "Pause"
    )


def toggle_record(event):
    global recording, csv_file, csv_writer

    if not recording:
        csv_file = open("scope_capture.csv", "w", newline="")
        csv_writer = csv.writer(csv_file)
        csv_writer.writerow(["Time (s)", "CH1 (V)", "CH2 (V)"])
        recording = True
        record_button.label.set_text("Stop Rec")
    else:
        recording = False
        csv_file.close()
        csv_file = None
        csv_writer = None
        record_button.label.set_text("Record")


pause_button.on_clicked(toggle_pause)
record_button.on_clicked(toggle_record)


def update(frame):
    global recording

    # Read queued samples even when display is paused
    count = 0

    while count < 2000:
        try:
            t, v0, v1 = samples.get_nowait()
        except queue.Empty:
            break

        count += 1

        if recording and csv_writer:
            csv_writer.writerow([t, v0, v1])

        if not paused:
            times.append(t)
            ch0_data.append(v0)
            ch1_data.append(v1)

    if not times:
        return line0, line1

    t = np.array(times)
    v0 = np.array(ch0_data)
    v1 = np.array(ch1_data)

    window = time_slider.val
    end = t[-1]
    start = end - window

    # Optional rising-edge software trigger
    if trigger_check.get_status()[0]:
        level = trigger_slider.val
        crossings = np.where(
            (v0[:-1] < level) & (v0[1:] >= level)
        )[0]

        if len(crossings):
            trigger_t = t[crossings[-1] + 1]
            start = trigger_t - 0.2 * window
            end = start + window

    mask = (t >= start) & (t <= end)

    line0.set_data(t[mask], v0[mask])
    line1.set_data(t[mask], v1[mask])

    ax.set_xlim(start, end)
    ax.set_ylim(0, volt_slider.val)

    return line0, line1


ani = FuncAnimation(
    fig, update,
    interval=50,
    blit=False,
    cache_frame_data=False
)

try:
    plt.show()
finally:
    running = False
    thread.join(timeout=1.0)

    if csv_file:
        csv_file.close()

    ser.close()
