# `west`-based Custom ZMK Configuration for a Dongle version of the MoErgo Glove80

![MoErgo Logo](moergo_logo.png)

This template repository provides `west`-based ZMK configuration for a Dongle version of the MoErgo Glove80 wireless split contoured keyboard.
You can use this template repository to develop your own keymap and build your own ZMK firmware to run on your Glove80 using ZMK/Zephyr's upstream `west` toolchain.

**NOTE: You can also customize the layout of your Glove80 keyboard with the [Glove80 Layout Editor](https://my.glove80.com) web app, or the [official ZMK configuration repository template](https://github.com/moergo-sc/glove80-zmk-config).
For most users, the Glove80 Layout Editor is the recommended and simpler option. More information is available at the official MoErgo Glove80 Support site (see resources below).**

These steps will get you using your keymap on your keyboard in the fastest time possible. It uses the GitHub Actions feature to build your firmware online.

If you are looking to dig deeper into ZMK and develop new functionality, it is recommended to follow the steps of installing ZMK as found on the official ZMK documentation site (linked below).

## Resources
- The [official MoErgo Glove80 Support](https://moergo.com/glove80-support) web site. Glove80 documentation and other technical resources.
- The [official MoErgo Discord Server](https://moergo.com/discord). Instant conversations with other Glove80 users.

- The [official ZMK Documentation](https://zmk.dev/docs) web site. Find the answers to many of your questions about ZMK Firmware.
- The [official ZMK Discord Server](https://discord.gg/8cfMkQksSB). Instant conversations with other ZMK developers and users. Great technical resource!

- The [official Glove80 ZMK Distribution](https://github.com/moergo-sc/zmk). Repositiory for ZMK firmware customized for Glove80.

## Instructions
1. Log into, or sign up for, your personal GitHub account.
2. Create your own repository using this repository as a template ([instructions](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template])) and check it out on your local computer.
3. Add your chosen configuration such as keymap to the `config` directory as described in [the ZMK documentation](https://zmk.dev/docs/user-setup)
4. Commit and push your changes to your personal repo. Upon pushing it, GitHub Actions will start building a new version of your firmware with the updated keymap.

## Dongle Setup

> **Inspired by:** [hopg's ZMK repository](https://github.com/hopg/zmk/tree/slice-mk-glove80-rh-rgb) and [darknao's Per key/layer RGB underglow PR](https://github.com/moergo-sc/zmk/pull/36)

This guide explains how to configure a Glove80 keyboard with an nRF52840 dongle. This setup allows both Glove80 halves to work as Bluetooth peripherals with the dongle acting as the central device. It is for a battery efficiency-first setup where the Glove80 is deskbound and you don't want to be recharging the left half every few weeks. In my setup, the dongle is permanently plugged into a KVM and so dongle doesn't need to be moved.

**⚠️ WARNING:** This is not an official release from MoErgo. Proceed with caution. If the steps are not followed correctly you may damage your dongle and/or your Glove80. This setup has been tested and developed using the [MakerDiary nRF52840 MDK USB Dongle](https://wiki.makerdiary.com/nrf52840-mdk-usb-dongle/) since it is shipped with UF2 Bootloader. **This configuration has not been tested with other nRF52840 dongles**, so compatibility cannot be guaranteed.

### Features and Limitations

- Charge both halves of the Glove80 once every 4 months (often lasting even longer)
- RGB underglow rendering occurs only on peripheral devices; the dongle central does not render LEDs directly (indicators are only visible on connected Glove80 halves)
- Each half displays its own battery level on its own underglow LEDs (i.e. the left no longer displays the right half)
  - Remote peripheral battery fetching is intentionally avoided to minimize BLE traffic and power consumption
  - Conscious design decision: active BLE queries for cross-peripheral battery fetching contradict the battery-efficiency objective as it adds four extra BLE communications
  - For some early versions of the Glove80 with underglow LEDs only on the left half, only the left half's battery level will be displayed
- RGB underglow indicators changes from the standard Glove80:
  - The USB output will show the status of the dongle's USB output (central)
  - Each peripheral shows its local USB enumeration status at T3
  - Each half displays its own local battery level with color-coded indicators
- Semantic underglow property naming for dongle-central topology:
  - New properties: `bat-local` (local device battery), `bat-left`, `bat-right` (Glove80-specific)
  - Deprecated properties: `bat-lhs`, `bat-rhs` (legacy from left-central era) maintained for backwards compatibility
  - Central USB state indicator (`central-usb` property) shows dongle's USB connection status on left half
- If you decide to use a different dongle, you will need to update the dtsi and overlays of the board/shield otherwise the HID (scroll, num, caps locks) indicators will only intermittently work
  - The issue you may see is that the HID indicators would regularly not show when reconnecting to USB (usually after initial firmware flash and/or when the peripherals are not turned on early enough after the dongle is plugged in)
  - Sort of a non-issue since toggling one of the HID locks will force the indicators to display properly (at least until the next time the dongle is power-cycled)
  - The fix is to add one of the dongle's unused but existing GPIO to the matrix so that the dongle registers with the host as an 'active' HID keyboard
- Still allows to pair over Bluetooth with four different hosts if you want
- KVM compatibility: I had issues with the dongle plugged into the dedicated keyboard/mouse USB ports (the emulated ports that don't have the USB passthrough):
  - The issue I was having was that when I was over a certain typing speed (not very fast, ~30 WPM), the KVM would miss keys or repeat keys
  - My workaround was to use the [Handheld Scientific Bluetooth Adapter BT-500](http://handheldsci.com/wp/wp-content/uploads/Manual_Full_v5.4.5.pdf) in between the KVM and the dongle, purely for the USB bridging mode
  - It looks like the BT-500 is not readily available anymore and they have replaced it with the [BT-600](http://handheldsci.com/kb/). **⚠️ WARNING:** I have not tested the BT-600 so I can't confirm if the behaviour will be the same
- I didn't use the GitHub build workflow so it most likely won't work. I have included two scripts that were used to setup the environment (install all the requirements) and build all the firmware files
- I was working in WSL so I copy the files to my Windows environment at the end (which you can remove if you don't want that to happen)
- This worked for me but it may not for you. Please update as you see fit

### Dongle Reconnection

If the dongle doesn't reconnect after being removed and reinserted from your USB port, follow these steps:

1. Turn off both Glove80 halves
2. Remove the nRF52840 dongle from the USB port
3. Reinsert the nRF52840 dongle into the USB port
4. Turn on one Glove80 and start typing until you see a response
5. Turn on the other Glove80 and start typing until you see a response

**Note:** If this doesn't work on the first attempt, repeat the steps and wait a few seconds between each step.

### Building Firmware

#### Prerequisites

Ensure you have completed [ZMK's development setup](https://zmk.dev/docs/development/setup) and all dependencies are installed.

#### Importing a Custom Keymap

Export your keymap from the [Glove80 Layout Editor](https://my.glove80.com) and copy it to:
```bash
config/glove80.keymap
```
**Note:** The filename must be exactly `glove80.keymap`

#### Building

Navigate to the `app` directory and build firmware for all three devices:

```bash
cd app
```

**Glove80 Left Hand:**
```bash
west build -p -d build/glove80_lh -b glove80_lh
```

**Glove80 Right Hand:**
```bash
west build -p -d build/glove80_rh -b glove80_rh
```

**nRF52840 Dongle:**
```bash
west build -p -d build/dongle -b nordic_nrf52840_dongle_slicemk -- -DSHIELD=glove80_dongle
```

### Installing Firmware

#### Resetting Bluetooth Bonds

Before installing firmware, reset the Bluetooth pairing bonds on each device.

##### Glove80 Left Hand
1. Turn off the device via the power switch
2. Press and hold `Magic` + `3` while toggling the power switch on
3. Hold for 10 seconds, then turn off

##### Glove80 Right Hand
1. Turn off the device via the power switch
2. Press and hold `PgDn` + `8` while toggling the power switch on
3. Hold for 10 seconds, then turn off

##### nRF52840 Dongle

If you need to reset bonds on the dongle:

1. Build the settings reset firmware:
   ```bash
   west build -p -d build/settings_reset -b nice_nano -- -DSHIELD=settings_reset
   ```

2. Double-press the reset switch to enter DFU mode
3. Copy `app/build/settings_reset/zephyr/zmk.uf2` to the `BBOARDBOOT` USB Mass Storage device
4. Double-press reset again to re-enter DFU mode
5. Copy the dongle firmware to the `BBOARDBOOT` device

#### Installing Firmware Files

##### Glove80 Left Hand
1. Connect the left hand to your computer via USB
2. Press and hold `Magic` + `E` while toggling the power switch on
3. The device appears as `GLV80LHBOOT` USB Mass Storage
4. Copy `app/build/glove80_lh/zephyr/zmk.uf2` to the root directory

##### Glove80 Right Hand
1. Connect the right hand to your computer via USB
2. Press and hold `I` + `PgDn` while toggling the power switch on
3. The device appears as `GLV80RHBOOT` USB Mass Storage
4. Copy `app/build/glove80_rh/zephyr/zmk.uf2` to the root directory

##### nRF52840 Dongle
1. Double-press the reset switch to enter DFU mode
2. The device appears as `BBOARDBOOT` USB Mass Storage
3. Copy `app/build/dongle/zephyr/zmk.uf2` to the root directory

### Troubleshooting

#### General Steps

Before proceeding with specific troubleshooting, try the dongle reconnection steps in the [Dongle Reconnection](#dongle-reconnection) section above.

#### Clearing Bonds

If pairing issues persist after trying reconnection steps:

##### Glove80 Left Hand
1. Turn off the device
2. Press and hold `Magic` + `3` while toggling the power switch on
3. Hold for 10 seconds

##### Glove80 Right Hand
1. Turn off the device
2. Press and hold `PgDn` + `8` while toggling the power switch on
3. Hold for 10 seconds

##### nRF52840 Dongle
Follow the bond clearing steps outlined in the [Installing Firmware](#installing-firmware) section.

#### Viewing Logs

Logging is enabled by default on the nRF52840 dongle. To view logs for debugging:

```bash
sudo tio /dev/ttyACM0
```

This output can help diagnose connection and pairing issues.
