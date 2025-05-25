MemuBar - macOS Memory Monitor
================================

Installation Instructions for Personal Use:

1. Copy MemuBar.app to your Applications folder
2. Launch MemuBar from Applications
3. The app will appear in your menu bar with a memory chip icon
4. Click on the memory indicator to see detailed breakdown

Features:
- Real-time memory monitoring in menu bar
- Memory chip icon showing fill level based on usage
- Detailed memory breakdown showing App Memory (A), Wired (W), and Compressed (C)
- Live updating when menu is open
- Auto-refresh every 5 seconds

Note: 
- This is a personal-use build without App Store distribution
- On first launch, you may need to right-click and "Open" to bypass Gatekeeper
- The app will show in System Preferences > Security & Privacy if blocked

Technical Details:
- Shows accurate App Memory calculation based on internal + external page counts
- Compressed memory shown in MB when under 1GB
- All values display with 2 decimal precision
- XPC service for secure memory access
- Memory chip icon reflects current memory pressure

Troubleshooting:
- If the menu bar icon doesn't appear, check Activity Monitor for MemuBar processes
- Restart the app if memory values seem stuck
- The app requires macOS 15.4 or later

Version: 1.0 (Updated)
Built: May 2025
Updates: Memory chip icon, cleaned up info dialog
