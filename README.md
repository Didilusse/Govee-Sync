# Govee Sync for macOS

**Control and synchronize your Govee Bluetooth LE smart lights directly from your Mac.**

Govee Sync is a lightweight, native macOS application that provides advanced control over your Govee smart lights using BLE. Go beyond the mobile app with features like low-latency screen mirroring, dynamic lighting scenes, and direct manual control, all from your menu bar or desktop.

## Features

* **Direct Manual Control**: Instantly set the power state, brightness, and any static color using a native color picker.

* **Dynamic Scenes**: A rich collection of built-in lighting effects to bring your room to life.

  * **Screen Sync**: Mirrors the average color of your screen onto your lights for an immersive viewing or gaming experience.

  * **Rainbow**: A smooth, continuous cycle through all colors of the spectrum.

  * **Pulse & Breathe**: A rhythmic pulsing or gentle breathing effect using your currently selected color.

  * **Thunderstorm**: Simulates a storm with dim blue light and random flashes of bright lightning.

  * **Candlelight**: A warm, flickering effect that mimics a real candle.

  * **Aurora**: A gentle, shifting wave of northern lights-inspired colors.

  * **Strobe**: A rapid flashing effect.

  * **And More Coming!**

* **Bluetooth LE Control**: Communicates directly with your Govee devices using your Mac's built-in Bluetooth. No cloud account or Wi-Fi required.

* **Persistent Settings**: Your preferences and last-used settings are saved and restored on app launch.

* **Automatic Scanning**: The app automatically scans for devices on launch for a seamless connection experience.

## Screenshots


<p align="center">
  <img src="https://github.com/user-attachments/assets/3baa400b-d01d-4978-8789-0d57b95ab57b" alt="Controls View" width="49%"/>
  <img src="https://github.com/user-attachments/assets/0bae50b4-3bed-4c02-ab51-12aeb5c63b08" alt="Scenes View" width="49%"/>
</p>

## Requirements

* **macOS**: macOS 13.0 (Ventura) or later.

  * *ScreenCaptureKit requires macOS 13.0+.*

* **Bluetooth**: A Mac with Bluetooth 4.0 (BLE) or later.

* **Govee Device**: A compatible Govee Bluetooth LE smart light.
   * Note: This app has been primarily tested with the H6195 model. While other models may work, they are not guaranteed. If you encounter issues with a different model, please open an issue!


## Installation & Usage

1. **Download**: Coming Soon

## How It Works

This application is built entirely in Swift and leverages modern Apple frameworks for a native, efficient experience.

* **UI**: The user interface is built with **SwiftUI**, ensuring a clean, modern, and responsive layout that feels at home on macOS.

* **Bluetooth Communication**: Device control is handled through **CoreBluetooth**. The app scans for peripherals, connects, and discovers the specific BLE Service and Characteristic used by Govee devices to send commands. All commands are constructed as byte packets according to the known Govee BLE API.

* **Screen Mirroring**: The screen mirroring feature is powered by Apple's **ScreenCaptureKit**. This modern framework provides a low-latency stream of screen frames. For each frame, the app calculates the average color using **CoreImage** filters and sends the result to the light in near real-time.

## Contributing

Contributions are welcome! Whether it's a bug report, a feature request, or a pull request, your help is appreciated.

Please try to follow the existing code style and provide clear descriptions of your changes.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
