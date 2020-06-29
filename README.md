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

## Caveats

Tested on a Radiomaster TX16S with OpenTX 2.3.9 (and 2.3.10 nightlies)

## Copyright and Licence

(c) Jonathan Hudson 2020

GPL Version 3 or later.
