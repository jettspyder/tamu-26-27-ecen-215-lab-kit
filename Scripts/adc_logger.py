import serial
import csv
import time

# serial port configuration
SERIAL_PORT = "/dev/ttyACM0" # exact path may vary
BAUD_RATE = 115200 # symbols/s

# output CSV file
OUTPUT_FILE = "capstone/adc_readings.csv"

# open serial connection
ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)

# open CSV file
with open(OUTPUT_FILE, "w", newline="") as file:

    writer = csv.writer(file)

    # CSV header
    writer.writerow([
        "Time (ms)",
        "Channel 0 Raw",
        "Channel 0 Voltage (mV)",
        "Channel 1 Raw",
        "Channel 1 Voltage (mV)"
    ])

    print("Recording ADC data...")
    print("Press Ctrl+C to stop.")

    try:
        while True:

            # read serial data
            line = ser.readline().decode(
                "utf-8", errors="ignore"
            ).strip()

            if not line:
                continue

            # split CSV data
            values = line.split(",")

            # verify correct number of columns
            if len(values) == 5:

                try:
                    values = [int(v) for v in values]
                except ValueError:
                    continue

                # save data
                writer.writerow(values)

                # flush data to disk
                file.flush()

                # print readings
                print(values)

    except KeyboardInterrupt:
        print("\nRecording stopped.")

ser.close()