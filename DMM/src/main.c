#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/adc.h>
#include <zephyr/shell/shell.h>
#include <zephyr/sys/atomic.h>
#include <zephyr/sys/printk.h>

#include <stdint.h>
#include <errno.h>

/* =========================================================
 * ADC CONFIGURATION
 * ========================================================= */

#define ADC_NODE DT_NODELABEL(adc)

#define ADC_RESOLUTION      12
#define ADC_GAIN_SETTING    ADC_GAIN_1_6
#define ADC_REF_SETTING     ADC_REF_INTERNAL
#define ADC_ACQUISITION     ADC_ACQ_TIME(ADC_ACQ_TIME_MICROSECONDS, 40)

#define NUM_CHANNELS        5
#define NUM_SAMPLES         64
#define REFRESH_MS          500

#define ADC_FULL_SCALE      3.6f
#define ADC_MAX_COUNT       (1 << ADC_RESOLUTION)

/* =========================================================
 * MEASUREMENT CIRCUIT PARAMETERS
 * Modify these to match the external analog circuitry.
 * ========================================================= */

/* DC voltage measurement */
#define VOLTAGE_R1          90000.0f
#define VOLTAGE_R2          10000.0f

/* DC current measurement */
#define CURRENT_SHUNT       0.1f
#define CURRENT_GAIN        33.0f

/* Resistance measurement */
#define RESISTANCE_REF      10000.0f
#define EXCITATION_VOLTAGE  3.3f

/* Capacitance measurement */
#define CAPACITANCE_MAX     100.0e-6f

/* Inductance measurement */
#define INDUCTANCE_MAX      100.0e-3f

/* Analog front-end full-scale output */
#define INPUT_FULL_SCALE    3.3f

/* ADC calibration */
#define ADC_CAL_GAIN        1.0f
#define ADC_CAL_OFFSET      0.0f

/* =========================================================
 * MEASUREMENT MODES
 * ========================================================= */

typedef enum {
    MODE_VOLTAGE = 0,
    MODE_CURRENT,
    MODE_RESISTANCE,
    MODE_CAPACITANCE,
    MODE_INDUCTANCE
} measurement_mode_t;

static atomic_t current_mode = ATOMIC_INIT(MODE_VOLTAGE);
static atomic_t measurement_enabled = ATOMIC_INIT(1);

static const char *const mode_names[] = {
    "DC Voltage",
    "DC Current",
    "Resistance",
    "Capacitance",
    "Inductance"
};

/* =========================================================
 * ADC DEVICE
 * ========================================================= */

static const struct device *adc_dev =
    DEVICE_DT_GET(ADC_NODE);

/*
 * nRF52832 SAADC positive input selection:
 *
 * 1 = AIN0 = P0.02
 * 2 = AIN1 = P0.03
 * 3 = AIN2 = P0.04
 * 4 = AIN3 = P0.05
 * 5 = AIN4 = P0.28
 */

static const uint8_t adc_inputs[NUM_CHANNELS] = {
    1, 2, 3, 4, 5
};

/* =========================================================
 * ADC INITIALIZATION
 * ========================================================= */

static int adc_init(void)
{
    int ret;

    if (!device_is_ready(adc_dev)) {
        printk("ADC device is not ready.\n");
        return -ENODEV;
    }

    for (int i = 0; i < NUM_CHANNELS; i++) {

        struct adc_channel_cfg channel_cfg = {
            .gain = ADC_GAIN_SETTING,
            .reference = ADC_REF_SETTING,
            .acquisition_time = ADC_ACQUISITION,
            .channel_id = i,
            .differential = 0,
            .input_positive = adc_inputs[i]
        };

        ret = adc_channel_setup(adc_dev, &channel_cfg);

        if (ret < 0) {
            printk("ADC channel %d setup failed: %d\n",
                   i, ret);

            return ret;
        }
    }

    /* Perform initial SAADC offset calibration */

    int16_t sample;

    struct adc_sequence calibration_sequence = {
        .channels = BIT(0),
        .buffer = &sample,
        .buffer_size = sizeof(sample),
        .resolution = ADC_RESOLUTION,
        .calibrate = true
    };

    ret = adc_read(adc_dev, &calibration_sequence);

    if (ret < 0) {
        printk("ADC calibration failed: %d\n", ret);
        return ret;
    }

    printk("ADC initialized successfully.\n");

    return 0;
}

/* =========================================================
 * ADC SAMPLING
 * ========================================================= */

static int read_adc_voltage(uint8_t channel, float *voltage)
{
    int ret;
    int16_t sample;
    int32_t sum = 0;

    struct adc_sequence sequence = {
        .channels = BIT(channel),
        .buffer = &sample,
        .buffer_size = sizeof(sample),
        .resolution = ADC_RESOLUTION
    };

    /* Discard first sample after selecting the channel */

    ret = adc_read(adc_dev, &sequence);

    if (ret < 0) {
        return ret;
    }

    /* Collect and average ADC samples */

    for (int i = 0; i < NUM_SAMPLES; i++) {

        ret = adc_read(adc_dev, &sequence);

        if (ret < 0) {
            return ret;
        }

        sum += sample;
    }

    float average = (float)sum / NUM_SAMPLES;

    /* Prevent small negative readings near ground */

    if (average < 0.0f) {
        average = 0.0f;
    }

    /* Convert ADC counts to voltage */

    *voltage = average *
               ADC_FULL_SCALE /
               ADC_MAX_COUNT;

    /* Apply software calibration */

    *voltage = ((*voltage * ADC_CAL_GAIN)
               + ADC_CAL_OFFSET) / 2;

    if (*voltage < 0.0f) {
        *voltage = 0.0f;
    }

    return 0;
}

/* =========================================================
 * MEASUREMENT CONVERSION FUNCTIONS
 * ========================================================= */

static float calculate_voltage(float adc_voltage)
{
    return adc_voltage *
           (VOLTAGE_R1 + VOLTAGE_R2) /
           VOLTAGE_R2 / 10.0f;
}

static float calculate_current(float adc_voltage)
{
    return adc_voltage /
           (CURRENT_SHUNT * CURRENT_GAIN);
}

static float calculate_resistance(float adc_voltage)
{
    /* Detect open circuit or resistance overrange */

    if (adc_voltage >= EXCITATION_VOLTAGE - 0.005f) {
        return -1.0f;
    }

    return RESISTANCE_REF * adc_voltage /
           (EXCITATION_VOLTAGE - adc_voltage);
}

static float calculate_capacitance(float adc_voltage)
{
    return CAPACITANCE_MAX *
           adc_voltage /
           INPUT_FULL_SCALE;
}

static float calculate_inductance(float adc_voltage)
{
    return INDUCTANCE_MAX *
           adc_voltage /
           INPUT_FULL_SCALE;
}

/* =========================================================
 * DISPLAY FUNCTIONS
 * ========================================================= */

static void display_voltage(float voltage)
{
    if (voltage < 1.0f) {
        printk("%.3f mV", (double)(voltage * 1000.0f));
    } else {
        printk("%.4f V", (double)voltage);
    }
}

static void display_current(float current)
{
    if (current < 0.001f) {
        printk("%.3f uA", (double)(current * 1.0e6f));
    } else if (current < 1.0f) {
        printk("%.3f mA", (double)(current * 1000.0f));
    } else {
        printk("%.4f A", (double)current);
    }
}

static void display_resistance(float resistance)
{
    if (resistance < 0.0f) {
        printk("OL");
    } else if (resistance >= 1.0e6f) {
        printk("%.3f MOhm",
               (double)(resistance / 1.0e6f));
    } else if (resistance >= 1000.0f) {
        printk("%.3f kOhm",
               (double)(resistance / 1000.0f));
    } else {
        printk("%.3f Ohm", (double)resistance);
    }
}

static void display_capacitance(float capacitance)
{
    if (capacitance >= 1.0e-3f) {
        printk("%.3f mF",
               (double)(capacitance * 1.0e3f));
    } else if (capacitance >= 1.0e-6f) {
        printk("%.3f uF",
               (double)(capacitance * 1.0e6f));
    } else if (capacitance >= 1.0e-9f) {
        printk("%.3f nF",
               (double)(capacitance * 1.0e9f));
    } else {
        printk("%.3f pF",
               (double)(capacitance * 1.0e12f));
    }
}

static void display_inductance(float inductance)
{
    if (inductance >= 1.0f) {
        printk("%.4f H", (double)inductance);
    } else if (inductance >= 1.0e-3f) {
        printk("%.3f mH",
               (double)(inductance * 1.0e3f));
    } else {
        printk("%.3f uH",
               (double)(inductance * 1.0e6f));
    }
}

/* =========================================================
 * MEASUREMENT PROCESSING
 * ========================================================= */

static void perform_measurement(measurement_mode_t mode)
{
    float adc_voltage;
    int ret;

    ret = read_adc_voltage((uint8_t)mode, &adc_voltage);

    if (ret < 0) {
        printk("ADC read error: %d\n", ret);
        return;
    }

    printk("[%s] ADC: %.4f V | Measured: ",
           mode_names[mode],
           (double)adc_voltage);

    switch (mode) {

        case MODE_VOLTAGE:
            display_voltage(
                calculate_voltage(adc_voltage));
            break;

        case MODE_CURRENT:
            display_current(
                calculate_current(adc_voltage));
            break;

        case MODE_RESISTANCE:
            display_resistance(
                calculate_resistance(adc_voltage));
            break;

        case MODE_CAPACITANCE:
            display_capacitance(
                calculate_capacitance(adc_voltage));
            break;

        case MODE_INDUCTANCE:
            display_inductance(
                calculate_inductance(adc_voltage));
            break;

        default:
            printk("Invalid mode");
            break;
    }

    printk("\n");
}

/* =========================================================
 * TERMINAL COMMANDS
 * ========================================================= */

static int set_mode(const struct shell *sh,
                    measurement_mode_t mode)
{
    atomic_set(&current_mode, mode);

    shell_print(sh, "Mode selected: %s",
                mode_names[mode]);

    return 0;
}

static int cmd_voltage(const struct shell *sh,
                       size_t argc, char **argv)
{
    return set_mode(sh, MODE_VOLTAGE);
}

static int cmd_current(const struct shell *sh,
                       size_t argc, char **argv)
{
    return set_mode(sh, MODE_CURRENT);
}

static int cmd_resistance(const struct shell *sh,
                          size_t argc, char **argv)
{
    return set_mode(sh, MODE_RESISTANCE);
}

static int cmd_capacitance(const struct shell *sh,
                           size_t argc, char **argv)
{
    return set_mode(sh, MODE_CAPACITANCE);
}

static int cmd_inductance(const struct shell *sh,
                          size_t argc, char **argv)
{
    return set_mode(sh, MODE_INDUCTANCE);
}

static int cmd_start(const struct shell *sh,
                     size_t argc, char **argv)
{
    atomic_set(&measurement_enabled, 1);

    shell_print(sh, "Measurements started.");

    return 0;
}

static int cmd_stop(const struct shell *sh,
                    size_t argc, char **argv)
{
    atomic_set(&measurement_enabled, 0);

    shell_print(sh, "Measurements stopped.");

    return 0;
}

static int cmd_status(const struct shell *sh,
                      size_t argc, char **argv)
{
    shell_print(sh, "Current mode: %s",
                mode_names[atomic_get(&current_mode)]);

    shell_print(sh, "Measurements: %s",
                atomic_get(&measurement_enabled) ?
                "Running" : "Stopped");

    return 0;
}

/* Register shell commands */

SHELL_STATIC_SUBCMD_SET_CREATE(
    dmm_commands,

    SHELL_CMD(voltage, NULL,
              "Select DC voltage mode", cmd_voltage),

    SHELL_CMD(current, NULL,
              "Select DC current mode", cmd_current),

    SHELL_CMD(resistance, NULL,
              "Select resistance mode", cmd_resistance),

    SHELL_CMD(capacitance, NULL,
              "Select capacitance mode", cmd_capacitance),

    SHELL_CMD(inductance, NULL,
              "Select inductance mode", cmd_inductance),

    SHELL_CMD(start, NULL,
              "Start measurements", cmd_start),

    SHELL_CMD(stop, NULL,
              "Stop measurements", cmd_stop),

    SHELL_CMD(status, NULL,
              "Display current status", cmd_status),

    SHELL_SUBCMD_SET_END
);

SHELL_CMD_REGISTER(dmm, &dmm_commands,
                   "DMM/LCR meter commands", NULL);

/* =========================================================
 * MAIN
 * ========================================================= */

int main(void)
{
    printk("\n");
    printk("====================================\n");
    printk("       nRF52 DK DMM/LCR Meter       \n");
    printk("====================================\n");

    if (adc_init() < 0) {
        printk("Initialization failed.\n");
        return -1;
    }

    printk("\nAvailable commands:\n");
    printk("  dmm voltage\n");
    printk("  dmm current\n");
    printk("  dmm resistance\n");
    printk("  dmm capacitance\n");
    printk("  dmm inductance\n");
    printk("  dmm start\n");
    printk("  dmm stop\n");
    printk("  dmm status\n\n");

    while (1) {

        if (atomic_get(&measurement_enabled)) {

            measurement_mode_t mode =
                (measurement_mode_t)
                atomic_get(&current_mode);

            perform_measurement(mode);
        }

        k_msleep(REFRESH_MS);
    }

    return 0;
}