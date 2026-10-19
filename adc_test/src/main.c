// zephyr includes
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/adc.h> // kconfig extension throws a warning here, but this is the correct header to include for ADC API
#include <zephyr/sys/printk.h>
#include <zephyr/dt-bindings/adc/nrf-saadc.h>
// standard includes
#include <stdio.h>

#define ADC_NODE DT_NODELABEL(adc)
#define ADC_RESOLUTION 12

// ADC sample buffer
static const struct device *adc_dev = DEVICE_DT_GET(ADC_NODE);

static int16_t sample_buffer[2]; // can increase # of channels here

int main(void)
{
    int ret; // return value for ADC API calls

    // check if ADC device is ready
    if (!device_is_ready(adc_dev)) {
        printk("ADC device not ready!\n");
        return 0;
    }

    // configure ADC channel 0 (AIN0 / P0.02)
    struct adc_channel_cfg channel0_cfg = {
        .gain = ADC_GAIN_1_6,
        .reference = ADC_REF_INTERNAL,
        .acquisition_time = ADC_ACQ_TIME_DEFAULT,
        .channel_id = 0,
        .input_positive = NRF_SAADC_AIN0,
    };

    // configure ADC channel 1 (AIN1 / P0.03)
    struct adc_channel_cfg channel1_cfg = {
        .gain = ADC_GAIN_1_6,
        .reference = ADC_REF_INTERNAL,
        .acquisition_time = ADC_ACQ_TIME_DEFAULT,
        .channel_id = 1,
        .input_positive = NRF_SAADC_AIN1,
    };

    // error handling for channel setup
    ret = adc_channel_setup(adc_dev, &channel0_cfg);

    if (ret != 0) {
        printk("Channel 0 setup failed: %d\n", ret);
        return 0;
    }

    ret = adc_channel_setup(adc_dev, &channel1_cfg);

    if (ret != 0) {
        printk("Channel 1 setup failed: %d\n", ret);
        return 0;
    }

    // configure ADC sampling sequence
    struct adc_sequence sequence = {
        .channels = BIT(0) | BIT(1), // channel mask tells driver to sample both channels
        .buffer = sample_buffer,
        .buffer_size = sizeof(sample_buffer),
        .resolution = ADC_RESOLUTION,
    };

    printk("Starting ADC sampling...\n");

    while (1) {

        int64_t timestamp = k_uptime_get();
        ret = adc_read(adc_dev, &sequence);

        if (ret == 0) {
        // store the raw ADC values in local buffer for conversion to mV
        // sequential sample, not simultaneous
            int32_t voltage0 = sample_buffer[0];
            int32_t voltage1 = sample_buffer[1];

            // convert raw ADC values to millivolts
            adc_raw_to_millivolts(
                600,
                ADC_GAIN_1_6,
                ADC_RESOLUTION,
                &voltage0
            );

            adc_raw_to_millivolts(
                600,
                ADC_GAIN_1_6,
                ADC_RESOLUTION,
                &voltage1
            );

            /*
            // nice output for live reading
            printk("CH0: %d (%d mV) | CH1: %d (%d mV)\n | DIFF: %d mV\n",
                   sample_buffer[0],
                   voltage0,
                   sample_buffer[1],
                   voltage1,
                   voltage1 - voltage0); */

            // csv format for logging to file, python script adc_logger.py
            // timestamp, CH0 raw, CH0 mV, CH1 raw, CH1 mV
            printk("%lld,%d,%d,%d,%d\n",
                   timestamp,
                   sample_buffer[0],
                   voltage0,
                   sample_buffer[1],
                   voltage1);
        }
        else {
            printk("ADC read failed: %d\n", ret);
        }

        k_msleep(0.01); // k_msleep(x): x ms between reads, 0.5 ms = 500 us, 1 ms = 1000 us
    }

    return 0;
}