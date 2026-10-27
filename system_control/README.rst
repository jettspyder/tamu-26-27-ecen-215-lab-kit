Overview
********
IMPORTANT: This program is designed for the nRF52 DK with on-board nRF52832 SoC. 

The System Control code takes input from the console to activate subsystems. 
The program controls the switches which will activate each subsystem. Input is read from the console and sent to the MCU via serial. 

Directory Structure
********
- build: Contains all build information
- src: Contains C source code
- README.rst: This document. User technical documentation. 
- prj.conf: Basic configuration for activating peripheral and output devices, etc. 
- app.overlay: Advanced configuration for IO. 

Use
********
With board connected over USB, open the serial terminal associated with the development kit. Ex: Linux (Bash): $ screen /dev/ttyACM0 115200
