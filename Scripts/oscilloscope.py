
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

def rising_crossings(t, v, level):
    """
    Find rising-edge crossing times using linear interpolation.
    """
    crossings = []

    for i in range(len(v) - 1):
        if v[i] < level <= v[i + 1]:

            dv = v[i + 1] - v[i]

            if dv == 0:
                continue

            fraction = (level - v[i]) / dv

            crossing_time = (
                t[i] + fraction * (t[i + 1] - t[i])
            )

            crossings.append(crossing_time)

    return np.array(crossings)


def calculate_measurements(t, v):
    """
    Calculate waveform measurements for one channel.

    Returns:
        Average voltage
        Peak-to-peak voltage
        Peak amplitude
        Frequency
    """

    if len(v) < 10:
        return None

    # Average voltage
    v_avg = np.mean(v)

    # Peak-to-peak voltage
    v_pp = np.max(v) - np.min(v)

    # Peak amplitude
    v_peak = v_pp / 2.0

    # Detect rising crossings at the average voltage
    crossings = rising_crossings(t, v, v_avg)

    frequency = None

    if len(crossings) >= 2:

        periods = np.diff(crossings)

        # Remove invalid periods
        periods = periods[periods > 0]

        if len(periods) > 0:
            frequency = 1.0 / np.mean(periods)

    return {
        "avg": v_avg,
        "vpp": v_pp,
        "peak": v_peak,
        "freq": frequency
    }


def calculate_phase(t, v0, v1, f0, f1):
    """
    Calculate CH2 phase relative to CH1.

    Positive phase means CH2 leads CH1.
    Negative phase means CH2 lags CH1.
    """

    if f0 is None or f1 is None:
        return None

    # Require approximately equal frequencies
    if abs(f0 - f1) / max(f0, f1) > 0.05:
        return None

    frequency = (f0 + f1) / 2.0
    period = 1.0 / frequency

    crossings0 = rising_crossings(
        t, v0, np.mean(v0)
    )

    crossings1 = rising_crossings(
        t, v1, np.mean(v1)
    )

    if len(crossings0) == 0 or len(crossings1) == 0:
        return None

    # Compare CH2 crossings to the nearest CH1 crossings
    phase_values = []

    for t1 in crossings1:

        differences = crossings0 - t1

        # Wrap differences to +/- half a period
        differences = (
            differences + period / 2
        ) % period - period / 2

        nearest_difference = differences[
            np.argmin(np.abs(differences))
        ]

        phase = 360.0 * nearest_difference / period

        phase_values.append(phase)

    if not phase_values:
        return None

    return np.mean(phase_values)

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

fig, ax = plt.subplots(figsize=(15, 8))

plt.subplots_adjust(
    left=0.08,
    right=0.72,
    bottom=0.32,
    top=0.92
)

# Measurement panel
measurement_text = fig.text(
    0.75,
    0.88,
    "",
    fontsize=10,
    family="monospace",
    verticalalignment="top",
    bbox=dict(
        boxstyle="round",
        facecolor="whitesmoke",
        edgecolor="gray"
    )
)

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
time_ax = plt.axes(
    (0.18, 0.22, 0.49, 0.03)
)
time_slider = Slider(
    time_ax, "Window (s)", 0.1, 10.0,
    valinit=2.0
)

# Vertical range slider

# Vertical range slider
volt_ax = plt.axes(
    (0.18, 0.17, 0.49, 0.03)
)
volt_slider = Slider(
    volt_ax, "Max V", 0.5, 3.6,
    valinit=3.3
)

# Trigger level
trigger_ax = plt.axes(
    (0.18, 0.12, 0.49, 0.03)
)
trigger_slider = Slider(
    trigger_ax, "Trigger V", 0.0, 3.3,
    valinit=1.5
)

# Buttons
pause_ax = plt.axes(
    (0.08, 0.025, 0.15, 0.05)
)
record_ax = plt.axes(
    (0.28, 0.025, 0.15, 0.05)
)
trigger_check_ax = plt.axes(
    (0.48, 0.015, 0.20, 0.065)
)

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

# Channel visibility controls
channel_check_ax = plt.axes(
    (0.75, 0.18, 0.20, 0.09)
)

channel_check = CheckButtons(
    channel_check_ax,
    ["CH1", "CH2"],
    [True, True]
)

channel_check_ax.set_title("Channels", fontsize=10)


# Cursor visibility controls
cursor_check_ax = plt.axes(
    (0.75, 0.04, 0.20, 0.09)
)

cursor_check = CheckButtons(
    cursor_check_ax,
    ["Time Cursors", "Voltage Cursors"],
    [False, False]
)

cursor_check_ax.set_title("Cursors", fontsize=10)


# Channel visibility callback
def toggle_channel(label):

    if label == "CH1":
        line0.set_visible(not line0.get_visible())

    elif label == "CH2":
        line1.set_visible(not line1.get_visible())

    fig.canvas.draw_idle()


channel_check.on_clicked(toggle_channel)

# ==================================================
# Measurement cursors
# ==================================================

# Time cursor positions as fractions of the time window
time_cursor_positions = [0.25, 0.75]

# Voltage cursor positions in volts
voltage_cursor_positions = [0.75, 1.25]

# Currently selected cursor
active_cursor = None


# Vertical time cursors
time_cursor1 = ax.axvline(
    x=0,
    color="limegreen",
    linestyle="--",
    linewidth=1.5,
    visible=False
)

time_cursor2 = ax.axvline(
    x=0,
    color="limegreen",
    linestyle=":",
    linewidth=1.5,
    visible=False
)


# Horizontal voltage cursors
voltage_cursor1 = ax.axhline(
    y=voltage_cursor_positions[0],
    color="magenta",
    linestyle="--",
    linewidth=1.5,
    visible=False
)

voltage_cursor2 = ax.axhline(
    y=voltage_cursor_positions[1],
    color="magenta",
    linestyle=":",
    linewidth=1.5,
    visible=False
)


# Cursor measurement display
cursor_text = fig.text(
    0.75,
    0.54,
    "",
    fontsize=10,
    family="monospace",
    verticalalignment="top",
    bbox=dict(
        boxstyle="round",
        facecolor="whitesmoke",
        edgecolor="gray"
    )
)

cursor_text.set_visible(False)

def update_cursors():

    time_enabled, voltage_enabled = (
        cursor_check.get_status()
    )

    # Current horizontal axis limits
    xmin, xmax = ax.get_xlim()
    window = xmax - xmin

    # Calculate absolute time cursor positions
    t1 = xmin + time_cursor_positions[0] * window
    t2 = xmin + time_cursor_positions[1] * window

    # Voltage cursor positions
    v1 = voltage_cursor_positions[0]
    v2 = voltage_cursor_positions[1]

    # Update cursor positions
    time_cursor1.set_xdata([t1, t1])
    time_cursor2.set_xdata([t2, t2])

    voltage_cursor1.set_ydata([v1, v1])
    voltage_cursor2.set_ydata([v2, v2])

    # Update cursor visibility
    time_cursor1.set_visible(time_enabled)
    time_cursor2.set_visible(time_enabled)

    voltage_cursor1.set_visible(voltage_enabled)
    voltage_cursor2.set_visible(voltage_enabled)

    # Build cursor measurement panel
    text = (
        "CURSOR MEASUREMENTS\n"
        "----------------------\n"
    )

    if time_enabled:

        delta_t = abs(t2 - t1)

        if delta_t > 1e-9:
            frequency_text = f"{1.0 / delta_t:.3f} Hz"
        else:
            frequency_text = "---"

        text += (
            "\nTIME CURSORS\n"
            f"T1:   {t1:.4f} s\n"
            f"T2:   {t2:.4f} s\n"
            f"dT:   {delta_t * 1000:.3f} ms\n"
            f"1/dT: {frequency_text}\n"
        )

    if voltage_enabled:

        delta_v = abs(v2 - v1)

        text += (
            "\nVOLTAGE CURSORS\n"
            f"V1:   {v1:.3f} V\n"
            f"V2:   {v2:.3f} V\n"
            f"dV:   {delta_v:.3f} V\n"
        )

    cursor_text.set_text(text)

    cursor_text.set_visible(
        time_enabled or voltage_enabled
    )

def toggle_cursors(label):

    global active_cursor

    active_cursor = None

    update_cursors()
    fig.canvas.draw_idle()


cursor_check.on_clicked(toggle_cursors)

# ==================================================
# Mouse interaction
# ==================================================

CURSOR_PICK_DISTANCE = 10  # pixels


def on_mouse_press(event):

    global active_cursor

    if event.inaxes != ax:
        return

    if event.button != 1:
        return

    active_cursor = None

    # Avoid interfering with toolbar pan/zoom
    toolbar = getattr(fig.canvas, "toolbar", None)

    if toolbar is not None and toolbar.mode:
        return

    time_enabled, voltage_enabled = (
        cursor_check.get_status()
    )

    candidates = []

    # Check vertical time cursors
    if time_enabled:

        time_lines = [
            time_cursor1,
            time_cursor2
        ]

        for i, cursor in enumerate(time_lines):

            cursor_x = cursor.get_xdata()[0]

            pixel_x = ax.transData.transform(
                (cursor_x, 0)
            )[0]

            distance = abs(event.x - pixel_x)

            candidates.append(
                (distance, "time", i)
            )

    # Check horizontal voltage cursors
    if voltage_enabled:

        for i, voltage in enumerate(
            voltage_cursor_positions
        ):

            pixel_y = ax.transData.transform(
                (0, voltage)
            )[1]

            distance = abs(event.y - pixel_y)

            candidates.append(
                (distance, "voltage", i)
            )

    # Select the closest cursor
    if candidates:

        distance, cursor_type, index = min(
            candidates,
            key=lambda item: item[0]
        )

        if distance <= CURSOR_PICK_DISTANCE:

            active_cursor = (
                cursor_type,
                index
            )


def on_mouse_move(event):

    if active_cursor is None:
        return

    if event.inaxes != ax:
        return

    cursor_type, index = active_cursor

    if cursor_type == "time":

        if event.xdata is None:
            return

        xmin, xmax = ax.get_xlim()

        if xmax <= xmin:
            return

        # Convert mouse position to window fraction
        fraction = (
            (event.xdata - xmin) /
            (xmax - xmin)
        )

        time_cursor_positions[index] = float(
            np.clip(fraction, 0.0, 1.0)
        )

    elif cursor_type == "voltage":

        if event.ydata is None:
            return

        ymin, ymax = ax.get_ylim()

        voltage_cursor_positions[index] = float(
            np.clip(event.ydata, ymin, ymax)
        )

    update_cursors()

    fig.canvas.draw_idle()


def on_mouse_release(event):

    global active_cursor

    active_cursor = None


# Register mouse events
fig.canvas.mpl_connect(
    "button_press_event",
    on_mouse_press
)

fig.canvas.mpl_connect(
    "motion_notify_event",
    on_mouse_move
)

fig.canvas.mpl_connect(
    "button_release_event",
    on_mouse_release
)

def update(frame):
    global recording

    # Read queued samples
    count = 0

    while count < 2000:
        try:
            t, v0, v1 = samples.get_nowait()

        except queue.Empty:
            break

        count += 1

        # Record data to CSV
        if recording and csv_writer:
            csv_writer.writerow([t, v0, v1])

        # Update display buffers
        if not paused:
            times.append(t)
            ch0_data.append(v0)
            ch1_data.append(v1)

    if len(times) < 10:

        update_cursors()

        return (
            line0,
            line1,
            measurement_text,
            cursor_text,
            time_cursor1,
            time_cursor2,
            voltage_cursor1,
            voltage_cursor2
        )

    t = np.array(times)
    v0 = np.array(ch0_data)
    v1 = np.array(ch1_data)

    # Time window
    window = time_slider.val

    end = t[-1]
    start = end - window

    # Software trigger
    if trigger_check.get_status()[0]:

        level = trigger_slider.val

        crossings = np.where(
            (v0[:-1] < level) &
            (v0[1:] >= level)
        )[0]

        if len(crossings) > 0:

            trigger_t = t[crossings[-1] + 1]

            start = trigger_t - 0.2 * window
            end = start + window

    # Select visible samples
    mask = (t >= start) & (t <= end)

    t_visible = t[mask]
    v0_visible = v0[mask]
    v1_visible = v1[mask]

    # Update waveforms
    line0.set_data(t_visible, v0_visible)
    line1.set_data(t_visible, v1_visible)

    ax.set_xlim(start, end)
    ax.set_ylim(0, volt_slider.val)
    update_cursors()

    # Calculate measurements
    m0 = calculate_measurements(t_visible, v0_visible)
    m1 = calculate_measurements(t_visible, v1_visible)

    if m0 is not None and m1 is not None:

        phase = calculate_phase(
            t_visible,
            v0_visible,
            v1_visible,
            m0["freq"],
            m1["freq"]
        )

        # Format frequency
        f0_text = (
            f"{m0['freq']:.2f} Hz"
            if m0["freq"] is not None
            else "---"
        )

        f1_text = (
            f"{m1['freq']:.2f} Hz"
            if m1["freq"] is not None
            else "---"
        )

        # Format phase
        phase_text = (
            f"{phase:+.1f} deg"
            if phase is not None
            else "---"
        )

        # Measurement panel
        text = (
            "WAVEFORM MEASUREMENTS\n"
            "----------------------\n\n"

            "CHANNEL 1\n"
            f"Average: {m0['avg']:.3f} V\n"
            f"Vpp:     {m0['vpp']:.3f} V\n"
            f"Peak:    {m0['peak']:.3f} V\n"
            f"Freq:    {f0_text}\n\n"

            "CHANNEL 2\n"
            f"Average: {m1['avg']:.3f} V\n"
            f"Vpp:     {m1['vpp']:.3f} V\n"
            f"Peak:    {m1['peak']:.3f} V\n"
            f"Freq:    {f1_text}\n\n"

            "PHASE DIFFERENCE\n"
            f"CH2 - CH1: {phase_text}\n"
        )

        measurement_text.set_text(text)

    return (
        line0,
        line1,
        measurement_text,
        cursor_text,
        time_cursor1,
        time_cursor2,
        voltage_cursor1,
        voltage_cursor2
    )


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
