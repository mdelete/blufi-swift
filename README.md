# bluefi-swift

Experimental Swift Framework + Example to connect ESP32 devices to WiFi using the [BluFi Protocol](https://docs.espressif.com/projects/esp-idf/en/latest/api-reference/bluetooth/esp_blufi.html).

[![Build Status](https://travis-ci.org/mdelete/BluFiExample.svg?branch=master)](https://travis-ci.org/mdelete/BluFiExample)

Features
--------

 * DH/AES/CRC
 * Get Wifi-List
 * Get Device-Status
 * Set STA using SSID and Password

TODOs
-----

 * Better error handling
 * SoftAP and WPA-Enterprise hooks

Links
-----

 * Contains a copy of [BigInt](https://github.com/attaswift/BigInt) for the DH-Key-Exchange, and [SwiftSpinner](https://github.com/icanzilb/SwiftSpinner) for a nice blocking activity indicator.
 * [BluFi API Guide](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/blufi.html)

License
-------
The code in this repository is published under the terms of the **MIT** License. See the **LICENSE** file for the complete license text.
