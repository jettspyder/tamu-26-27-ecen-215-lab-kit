Overview
********
IMPORTANT: This program is designed for the nRF52 DK with on-board nRF52832 SoC. 

The ADC Test code reads two channels of voltage and prints readings to the console. 
The program uses Channel 0 (AIN0) and Channel 1 (AIN1) with 12-bit sampling and 100 ksps sample rate. Internal 0.6 V reference with gain 1/6. Nominal full-scale measurement voltage range is 0-3.6 V. Measurements are single-ended and sequential. Readings output over UART. 

Directory Structure
********
- build: Contains all build information
- src: Contains C source code
- README.rst: This document. User technical documentation. 
- prj.conf: Basic configuration for activating peripheral and output devices, etc. 
- app.overlay: Advanced configuration for IO. 

Use
********

With board connected over USB, open the serial terminal associated with the development kit. 
Ex: Linux (Bash): 
$ screen /dev/ttyACM0 115200

Modifications
********

Example samples both channels every 500 ms (2 sps). Change the sampling interval by modifying k_msleep(500); with sleep time in ms. Actual rate depends on ADC and console overhead. 

Notes
********
