# Cider Remote Guide

## Getting Started

### Prerequisites
- Ensure that Cider is installed and running on your computer (Windows, macOS, or Linux).
- Your iPhone should be connected to the same local network as Cider (for LAN mode).
- For WAN mode, you can control Cider from anywhere, as long as both devices have internet access.
- Cider's RPC server should be enabled.

### Setting Up Cider Remote

#### LAN Mode (Local Area Network)
1. **Open Cider Remote on Your iPhone:**
   - Launch the Cider Remote app on your iPhone.
   - Tap on the "Add a New Cider Device" button. This will open a QR code scanner.

2. **Configure Cider to Pair with Your iPhone:**
   - On your computer, open Cider.
   - Navigate to **Settings > Connectivity**.
   - Click on the **Manage** button under the "Remote Devices" section.
   - Select **Create Remote**.
   - Set up a name for your remote device. A QR code will be generated.

3. **Connect Your iPhone to Cider (LAN Mode):**
   - Use the QR code scanner on your iPhone (from the Cider Remote app) to scan the QR code displayed on Cider.
   - Once scanned, your iPhone will be paired with Cider.

#### WAN Mode (Wide Area Network)
If you need to control Cider from a different network or while away from home, you can switch to WAN mode.

1. **Switch to WAN Mode:**
   - Follow steps 1 and 2 from LAN mode to add a new Cider device.
   - When prompted to select the connection method, choose **WAN** instead of **LAN**.
   - Continue pairing your iPhone with Cider by scanning the QR code as before.
   - Once paired, Cider Remote will allow you to control playback from anywhere with internet access (thanks to [localtunnel](https://theboroer.github.io/localtunnel-www/) ), not just on the same local network.

## Important Notes
- **LAN Mode:** Cider Remote works over a local network, using the RPC server on port **10767**. Ensure that both your iPhone and Cider are on the same network.
- **WAN Mode:** Cider Remote in WAN mode allows for control from anywhere with internet access. Be sure that both devices have a stable internet connection.
- **Firewall Settings:** If Cider Remote cannot connect to Cider, you may need to allow Cider or port **10767** through your computer’s firewall.
- **Connectivity:** Both the Cider RPC server and WebSocket need to be enabled in settings for Cider Remote to function correctly.

## Troubleshooting

### Common Issues & Solutions
- **Cider Remote Cannot Find Cider (LAN):**
  - Ensure that both your iPhone and Cider client are connected to the same local network.
  - Check if the RPC server is running on Cider (port 10767).
  - Restart both your iPhone and the Cider client to refresh the connection.
  - **Solution:** If the LAN connection fails, try using **WAN mode** to control Cider over the internet.

- **Firewall Issues:**
  - If you're using a firewall, make sure that Cider or port **10767** is allowed through.
  - On Windows, go to **Control Panel > System and Security > Windows Defender Firewall > Allow an app or feature through Windows Defender Firewall**. Ensure that Cider is listed and allowed.
  - On macOS, go to **System Preferences > Security & Privacy > Firewall > Firewall Options**, and add Cider to the list of allowed apps.
  - On Linux, use your distribution's firewall management tool to allow the necessary port.

- **QR Code Scanning Issues:**
  - Ensure that the QR code is clearly visible and well-lit when scanning with your iPhone.
  - If the scan fails, try moving your phone closer or further away from the screen.

By following these steps, you should be able to set up and use Cider Remote without any issues, whether on LAN or WAN.
