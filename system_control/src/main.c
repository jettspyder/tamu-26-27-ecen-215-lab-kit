#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/drivers/uart.h>
#include <zephyr/sys/printk.h>

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define GPIO_NODE DT_NODELABEL(gpio0)
#define UART_NODE DT_CHOSEN(zephyr_console)

#define NUM_SWITCHES 4
#define CMD_BUFFER_SIZE 64

// GPIO pin assignments
static const uint8_t switch_pins[NUM_SWITCHES] = {
    13, 14, 15, 16
};

// GPIO device
static const struct device *gpio_dev =
    DEVICE_DT_GET(GPIO_NODE);

// UART console device
static const struct device *uart_dev =
    DEVICE_DT_GET(UART_NODE);

// switch states
static uint8_t switch_states[NUM_SWITCHES] = {0};

// command buffer
static char cmd_buffer[CMD_BUFFER_SIZE];


// print command menu
void print_menu(void)
{
    printk("\n================================\n");
    printk("     nRF52 GPIO Controller\n");
    printk("================================\n");

    printk("Commands:\n");
    printk("  on <n>    - Turn switch n ON\n");
    printk("  off <n>   - Turn switch n OFF\n");
    printk("  all on    - Turn all switches ON\n");
    printk("  all off   - Turn all switches OFF\n");
    printk("  status    - Display switch states\n");
    printk("  help      - Display commands\n");

    printk("================================\n\n");
}


// set an individual switch
void set_switch(int switch_num, int state)
{
    if (switch_num < 1 || switch_num > NUM_SWITCHES) {
        printk("Invalid switch number.\n");
        return;
    }

    int index = switch_num - 1;

    int ret = gpio_pin_set(
        gpio_dev,
        switch_pins[index],
        state
    );

    if (ret < 0) {
        printk("GPIO write failed: %d\n", ret);
        return;
    }

    switch_states[index] = state;

    printk("Switch %d -> %s\n",
           switch_num,
           state ? "ON" : "OFF");
}


// set all switches
void set_all_switches(int state)
{
    for (int i = 1; i <= NUM_SWITCHES; i++) {
        set_switch(i, state);
    }
}


// display switch status
void print_status(void)
{
    printk("\nCurrent GPIO States:\n");

    for (int i = 0; i < NUM_SWITCHES; i++) {

        printk("Switch %d (P0.%02d): %s\n",
               i + 1,
               switch_pins[i],
               switch_states[i] ? "ON" : "OFF");
    }

    printk("\n");
}


// process terminal command
void process_command(char *command)
{
    int switch_num;

    if (strcmp(command, "help") == 0) {
        print_menu();
    }

    else if (strcmp(command, "status") == 0) {
        print_status();
    }

    else if (strcmp(command, "all on") == 0) {
        set_all_switches(1);
    }

    else if (strcmp(command, "all off") == 0) {
        set_all_switches(0);
    }

    else if (sscanf(command, "on %d", &switch_num) == 1 &&
             strncmp(command, "on ", 3) == 0) {

        set_switch(switch_num, 1);
    }

    else if (sscanf(command, "off %d", &switch_num) == 1 &&
             strncmp(command, "off ", 4) == 0) {

        set_switch(switch_num, 0);
    }

    else {
        printk("Unknown command: %s\n", command);
        printk("Type 'help' for commands.\n");
    }
}


// read command from UART
void read_command(void)
{
    int index = 0;
    unsigned char c;

    memset(cmd_buffer, 0, sizeof(cmd_buffer));

    while (1) {

        if (uart_poll_in(uart_dev, &c) == 0) {

            // enter key
            if (c == '\r' || c == '\n') {

                if (index > 0) {
                    cmd_buffer[index] = '\0';

                    printk("\n");

                    process_command(cmd_buffer);
                    break;
                }
            }

            // backspace
            else if (c == '\b' || c == 127) {

                if (index > 0) {
                    index--;

                    printk("\b \b");
                }
            }

            // normal character
            else if (index < CMD_BUFFER_SIZE - 1) {

                cmd_buffer[index++] = c;

                // echo character
                uart_poll_out(uart_dev, c);
            }
        }

        k_msleep(1);
    }
}


// main application
int main(void)
{
    int ret;

    // check UART device
    if (!device_is_ready(gpio_dev)) {
        printk("ERROR: GPIO device not ready!\n");
        return 0;
    }

    /* Check UART device */
    if (!device_is_ready(uart_dev)) {
        printk("ERROR: UART device not ready!\n");
        return 0;
    }

    // configure GPIO outputs
    for (int i = 0; i < NUM_SWITCHES; i++) {

        ret = gpio_pin_configure(
            gpio_dev,
            switch_pins[i],
            GPIO_OUTPUT_INACTIVE
        );

        if (ret < 0) {
            printk("GPIO configuration failed: %d\n", ret);
            return 0;
        }
    }

    printk("\nGPIO Controller Initialized!\n");

    print_menu();

    // main command loop
    while (1) {

        printk("GPIO> ");

        read_command();
    }

    return 0;
}