#include "Common.h"
#include "USBHost.h"
#include "SDCardVFS.h"
#include "FPGA.h"
#include "AqUartProtocol.h"
#include "WiFi.h"
#include "Bluetooth.h"
#include "FileServer.h"
#include "AqKeyboard.h"
#include "PowerLED.h"
#include "DisplayOverlay/DisplayOverlay.h"

#include <nvs_flash.h>
#include <esp_heap_caps.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

static const char *TAG = "main";

static void init() {
    // Init power LED
    getPowerLED()->init();

    // Initialize NVS
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        // NVS partition was truncated and needs to be erased
        ESP_ERROR_CHECK(nvs_flash_erase());

        // Retry nvs_flash_init
        ESP_ERROR_CHECK(nvs_flash_init());
    }

    // Initialize timezone, keyboard layout
    uint8_t video_timing_mode = 0;
    {
        nvs_handle_t h;
        if (nvs_open("settings", NVS_READONLY, &h) == ESP_OK) {
            char   tz[128];
            size_t len = sizeof(tz);
            if (nvs_get_str(h, "tz", tz, &len) == ESP_OK) {
                setenv("TZ", tz, 1);
            }

            uint8_t kblayout = 0;
            if (nvs_get_u8(h, "kblayout", &kblayout) == ESP_OK) {
                setKeyLayout((KeyLayout)kblayout);
            }

            uint8_t mouseDiv = 0;
            if (nvs_get_u8(h, "mouseDiv", &mouseDiv) == ESP_OK) {
                AqUartProtocol::instance().setMouseSensitivityDiv(mouseDiv);
            }

            if (nvs_get_u8(h, "videoTiming", &video_timing_mode) != ESP_OK) {
                video_timing_mode = 0;
            }
            nvs_close(h);
        }
    }

    // Initialize the event loop
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    getWiFi()->init();
    getBluetooth()->init();

    AqKeyboard::instance().init();
    SDCardVFS::instance().init();
    USBHost::instance().init();
    AqUartProtocol::instance().init();
    getFileServer()->init();

    // Initialize FPGA
    auto &fpga = FPGA::instance();
    fpga.init();
    fpga.loadDefaultBitstream();

    fpga.aqpSetVideoTimingMode(video_timing_mode);
}

extern "C" void app_main(void);

void app_main(void) {
    init();

    vTaskDelay(pdMS_TO_TICKS(100));

    auto displayOverlay = getDisplayOverlay();
    displayOverlay->init();

#if 0
    while (1) {
        char *buf = (char *)malloc(16384);
        if (buf) {
            vTaskList(buf);
            printf(
                "Name           State  Priority  Stack   Num     Core\n"
                "----------------------------------------------------\n"
                "%s\n",
                buf);
            free(buf);
        }
        vTaskDelay(pdMS_TO_TICKS(2000));
    }
#endif
    // while (1) {
    //     heap_caps_print_heap_info(MALLOC_CAP_DEFAULT);
    //     vTaskDelay(pdMS_TO_TICKS(2000));
    // }
}
