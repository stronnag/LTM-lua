# LTM-lua

## Introduction

This project provides an OpenTX LUA script that outputs LTM (INAV'S Lightweight Tememetry) on a serial port on an OpenTX / EdgeTX radio. It is designed to work with [INAV](https://github.com/iNavFlight/inav) as the telemetry provider.

Typical use case:

* Radiomaster TX16S radio (which has two normal / not inverted UARTS)
* Bluetooth module attached to a radio UART
* LTM aware ground station [mwp](https://github.com/stronnag/mwptools), ezgui, "mission planner for inav" or
* Antenna tracker that uses LTM.

## Installation and Usage

* Copy the script `ltm.lua` to the `SCRIPTS/FUNCTIONS' directory
* Create a directory, `SCRIPTS/FUNCTIONS/LTM`; copy the files `LTM/crsf.lua` and `LTM/config.lua` to that directory, such that the following directory structure is maintained.
```
    ├── SCRIPTS
    │   ├── FUNCTIONS
    │   │   ├── ltm.lua
    │   │   ├── LTM
    │   │   │   ├── crsf.lua
    │   │   │   ├── config.lua
```
* Enable the script as a Global Function or model specific Special Function.

Note that any Zip files in the release area will profile this directory structure.

The script may be invoked either on an external stimulus e.g. `Telemetry` or on a switch. See the OpenTX / TX vendor documentation for details on configuring your radio.

Note that the UARTs on the TX16S default to 115200 bps, so set BT devices accordingly.

Note that:

* OpenTX 2.3.9, a bug causes no power to be supplied to the TX16S UARTS; this is fixed in the 2.3.10 nightlies.
* OpenTX 2.3.10, a bug causes the Crossfire Flight Mode not to be set.
* OpenTX 2.3.11, the baud rate is set incorrectly for LUA ports, rendering the data unreadable.
* EdgeTX 2.7.1 and (2.8-dev of early May 2022) cannot set the LUA serial baud rate to other than the default of 115200.
* The telemetry provider must be INAV for some status related fields.

No known issues with
* OpenTx 2.3.15 / 2.3.14
* EdgeTX (other than setting baud rate)

## Configuration

There are a few user editable settings in the file `LTM/config.lua`; currently the user must edit this file directly as no radio UI is provdied.

In particular, the `onlyTracker` setting may be used to provide only GPS data for antenna trackers. See the comments in  `LTM/config.lua` for details.

The `S.baudrate` setting may be used to set the baud rate; if `S.baudrate` is `0`, then the device baud rate is unchanged, otherwise the specified baud rate is set. The default value is `0` (i.e. use radio setting).

## Audio

The `audio` directory contains two synthesised voice files, `ltmon.wav` and `ltmoff.wav` that may be placed in `SOUNDS/en` and used to provide audible indications (via Special Functions) that LTM forwarding is enabled / disabled.

### Logging

If the variable LOGGER is set to true,  LTM binary messages written to a LOG/ file (simulator and radio). It is not advised to do this on the radio.

In the simulator human readable debug messages are generated unconditionally.

## Caveats

Last Tested on a Radiomaster TX16S with OpenTX 2.3.15 and EdgeTX 2.7.1 and the internal module, FrSky D16 ompatible RX.
Requires Smartport or CRSF compatible RX on the aircraft.

The scripts have also been tested by others using Crossfire with Taranis x9D+se, OpenTX 2.3 +luac, full Crossfire TX, Nano RX and the [u360gts antenna tracker](https://github.com/raul-ortega/u360gts).

Other OpenTX/EdgeTX compatible radios and other RX radio systems (e.g. R9) are NOT tested and as I don't have such hardware.

## Copyright and Licence

(c) Jonathan Hudson 2020-2022

GPL Version 3 or later.
