# LTM-lua

## Introduction

This project provides an OpenTX LUA script that outputs LTM (inav's Lightweight Tememetry) on a serial port on an OpenTX radio.

Typical use case:

* Radiomaster TX16S radio (which has two normal / not inverted UARTS)
* Bluetooth module attached to a radio UART
* LTM aware ground station [mwp](https://github.com/stronnag/mwptools), ezgui, "mission planner for inav".

## Installation and Usage

* Copy the script `ltm.lua` to the `SCRIPTS/FUNCTIONS' directory
* Enable the script as a Global Function or model specific Special Function.

The script may be invoked either on an external stimulus e.g. `Telemetry` or on a switch. See the OpenTX / TX vendor documentation for details on configuring your radio.

Note that the UARTs on the TX16S default to 115200 bps, so set BT devices accordingly.

Note also that in OTX 2.3.9, a bug causes no power to be supplied to the TX16S UARTS; this is fixed in the 2.3.10 nightlies.

### Logging

If the variable LOGGER is set to true,  LTM binary messages written to a LOG/ file (simulator and radio)

In the simulator human readable debug messages are generated unconditionally.

## Caveats

Tested on a Radiomaster TX16S with OpenTX 2.3.9 (and 2.3.10 nightlies), internal module.
Requires smartport (e.g. Frsky D16) compatible RX on the aircraft.

## Copyright and Licence

(c) Jonathan Hudson 2020

GPL Version 3 or later.
