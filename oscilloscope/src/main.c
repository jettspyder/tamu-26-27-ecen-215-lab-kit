
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/adc.h>
#include <zephyr/drivers/uart.h>
#include <zephyr/dt-bindings/adc/nrf-adc.h>

#include <stdio.h>
#include <stdint.h>

#define ADC_NODE DT_NODELABEL(adc)
#define UART_NODE DT_CHOSEN(zephyr_console)

#define ADC_RESOLUTION 12
#define SAMPLE_PERIOD_MS 5

static const struct device *adc_dev =
    DEVICE_DT_GET(ADC_NODE);

static const struct device *uart_dev =
    DEVICE_DT_GET(UART_NODE);

static int16_t sample_buffer[2];

/* Transmit a string over UART */
static void uart_send(const char *str)
{
    while (*str) {
        uart_poll_out(uart_dev, (unsigned char)*str++);
    }
}

int main(void)
{
    int ret;
    char tx_buffer[64];

    if (!device_is_ready(adc_dev) ||
        !device_is_ready(uart_dev)) {
        return 0;
    }

    /* Channel 0: AIN0, P0.02 */
    struct adc_channel_cfg ch0 = {
        .gain = ADC_GAIN_1_6,
        .reference = ADC_REF_INTERNAL,
        .acquisition_time = ADC_ACQ_TIME_DEFAULT,
        .channel_id = 0,
        .input_positive = NRF_ADC_AIN0,
    };

    /* Channel 1: AIN1, P0.03 */
    struct adc_channel_cfg ch1 = {
        .gain = ADC_GAIN_1_6,
        .reference = ADC_REF_INTERNAL,
        .acquisition_time = ADC_ACQ_TIME_DEFAULT,
        .channel_id = 1,
        .input_positive = NRF_ADC_AIN1,
    };

    ret = adc_channel_setup(adc_dev, &ch0);
    if (ret < 0) {
        return 0;
    }

    ret = adc_channel_setup(adc_dev, &ch1);
    if (ret < 0) {
        return 0;
    }

    struct adc_sequence sequence = {
        .channels = BIT(0) | BIT(1),
        .buffer = sample_buffer,
        .buffer_size = sizeof(sample_buffer),
        .resolution = ADC_RESOLUTION,
    };

    uart_send("# nRF52 Oscilloscope Ready\r\n");
    uart_send("# Format: time_ms,ch0_raw,ch1_raw\r\n");

    int64_t next_sample = k_uptime_get();

    while (1) {

        ret = adc_read(adc_dev, &sequence);

        if (ret == 0) {

            int64_t timestamp = k_uptime_get();

            snprintf(tx_buffer, sizeof(tx_buffer),
                     "%lld,%d,%d\r\n",
                     (long long)timestamp,
                     sample_buffer[0],
                     sample_buffer[1]);

            uart_send(tx_buffer);
        }

        next_sample += SAMPLE_PERIOD_MS;

        int64_t remaining =
            next_sample - k_uptime_get();

        if (remaining > 0) {
            k_msleep((int32_t)remaining);
        } else {
            /* Missed deadline: resynchronize */
            next_sample = k_uptime_get();
        }
    }

    return 0;
}