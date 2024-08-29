# Cider Remote Guide

## Introduction
Cider Remote is an application designed for iPhone (with an Android version on the way) that allows you to control Cider with your phone. Whether you're using Cider on Windows, macOS, or Linux, you can manage your music playback seamlessly with Cider Remote. Cider Remote communicates with Cider through its RPC server.

## Getting Started

### Prerequisites
- Ensure that Cider is installed and running on your computer (Windows, macOS, or Linux).
- Your iPhone should be connected to the same local network as Cider.
- Cider's RPC server should be enabled.

### Setting Up Cider Remote
1. **Open Cider Remote on Your iPhone:**
   - Launch the Cider Remote app on your iPhone.
   - Tap on the "Add a New Cider Device" button. This will open a QR code scanner.

2. **Configure Cider to Pair with Your iPhone:**
   - On your computer, open Cider.
   - Navigate to **Settings > Connectivity**.
   - Click on the **Manage** button under the "Remote Devices" section.
   - Select **Create Remote**.
   - Set up a name for your remote device. A QR code will be generated.

3. **Connect Your iPhone to Cider:**
   - Use the QR code scanner on your iPhone (from the Cider Remote app) to scan the QR code displayed on Cider.
   - Once scanned, your iPhone will be paired with Cider.

## Important Notes
- **Local Connection Only:** Cider Remote works over a local network, using the RPC server on port **10767**. Ensure that both your iPhone and Cider are on the same network.
- **Firewall Settings:** If Cider Remote cannot connect to Cider, you may need to allow Cider or port **10767** through your computer’s firewall.
- **Connectivity:** Both the Cider RPC server and WebSocket need to be enabled in settings for Cider Remote to function correctly.

## Troubleshooting

### Common Issues & Solutions
- **Cider Remote Cannot Find Cider:**
  - Ensure that both your iPhone and Cider client are connected to the same local network.
  - Check if the RPC server is running on Cider (port 10767).
  - Restart both your iPhone and the Cider client to refresh the connection.

- **Firewall Issues:**
  - If you're using a firewall, make sure that Cider or port **10767** is allowed through.
  - On Windows, go to **Control Panel > System and Security > Windows Defender Firewall > Allow an app or feature through Windows Defender Firewall**. Ensure that Cider is listed and allowed.
  - On macOS, go to **System Preferences > Security & Privacy > Firewall > Firewall Options**, and add Cider to the list of allowed apps.
  - On Linux, use your distribution's firewall management tool to allow the necessary port.

- **QR Code Scanning Issues:**
  - Ensure that the QR code is clearly visible and well-lit when scanning with your iPhone.
  - If the scan fails, try moving your phone closer or further away from the screen.

By following these steps, you should be able to set up and use Cider Remote without any issues.
