#pragma once

// SD card interface
#define IOPIN_SD_WP_N     GPIO_NUM_5
#define IOPIN_SD_CD_N     GPIO_NUM_6
#define IOPIN_SD_SSEL_N   GPIO_NUM_17
#define IOPIN_SD_SCK      GPIO_NUM_15
#define IOPIN_SD_MOSI     GPIO_NUM_16
#define IOPIN_SD_MISO     GPIO_NUM_7

// SPI interface and FPGA programming interface
#define IOPIN_SPI_SSEL_N  GPIO_NUM_3
#define IOPIN_SPI_SCLK    GPIO_NUM_10
#define IOPIN_SPI_MOSI    GPIO_NUM_9
#define IOPIN_SPI_MISO    GPIO_NUM_11
#define IOPIN_SPI_NOTIFY  GPIO_NUM_12
#define IOPIN_FPGA_PROG_N GPIO_NUM_48
#define IOPIN_FPGA_DONE   GPIO_NUM_8

// UART interface
#define IOPIN_UART_TX     GPIO_NUM_21
#define IOPIN_UART_RX     GPIO_NUM_13
#define IOPIN_UART_RTS    GPIO_NUM_47
#define IOPIN_UART_CTS    GPIO_NUM_14

// USB host interface
#define IOPIN_USB_DM      GPIO_NUM_19
#define IOPIN_USB_DP      GPIO_NUM_20

// Power LED
#define IOPIN_LED         GPIO_NUM_4

// Debug UART
#define IOPIN_DBG_TXD0    GPIO_NUM_43
#define IOPIN_DBG_RXD0    GPIO_NUM_44

// Expansion pins
#define IOPIN_ESP_EXP0    GPIO_NUM_1
#define IOPIN_ESP_EXP1    GPIO_NUM_2
#define IOPIN_ESP_EXP2    GPIO_NUM_42
#define IOPIN_ESP_EXP3    GPIO_NUM_41
#define IOPIN_ESP_EXP4    GPIO_NUM_40
#define IOPIN_ESP_EXP5    GPIO_NUM_39
#define IOPIN_ESP_EXP6    GPIO_NUM_38
#define IOPIN_ESP_EXP7    GPIO_NUM_37
#define IOPIN_ESP_EXP8    GPIO_NUM_36
#define IOPIN_ESP_EXP9    GPIO_NUM_35
#define IOPIN_ESP_EXP10   GPIO_NUM_18
