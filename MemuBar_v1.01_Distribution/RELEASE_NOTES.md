# MemuBar v1.01 Release Notes

## 🎉 Major Update: Enhanced Memory Monitoring & Visual Improvements

### ✅ **Fixed Issues**
- **Fixed Active Memory Calculation**: Active Memory now matches Activity Monitor exactly using the correct formula (active + speculative pages)
- **Eliminated Negative Memory Values**: Robust validation prevents negative memory readings under high system pressure
- **Improved Memory Accuracy**: All memory statistics now precisely match macOS Activity Monitor

### 🎨 **Enhanced Visual Experience**
- **Smoother Icon Progression**: Added 10 granular levels for memory pressure indication instead of basic 3-level system
- **Enhanced Color Gradients**: Implemented sophisticated color transitions with 8 distinct pressure levels:
  - 🟢 Very Low (0-9%): Bright green
  - 🟢 Low (10-24%): Green  
  - 🟡 Low-Medium (25-39%): Light yellow
  - 🟡 Medium (40-59%): Yellow
  - 🟠 Medium-High (60-74%): Orange
  - 🔴 High (75-84%): Red
  - 🔴 Critical (85-100%): Dark red
  - ⚡ Extreme (>100%): Purple warning

- **Progressive Memory Chip Icon**: Segmented filling with smooth transitions for better visual feedback
- **Improved Menu Bar Integration**: Better contrast and visibility in both light and dark menu bar modes

### 🔧 **Technical Improvements**
- **Optimized Memory Calculations**: Uses `vm_stat.active_count + vm_stat.speculative_count` for Activity Monitor compatibility
- **Enhanced Error Handling**: Comprehensive validation and logging for debugging
- **Performance Optimizations**: Reduced CPU overhead with efficient system calls
- **Better XPC Communication**: Improved reliability between main app and helper service

### 📊 **Memory Statistics Display**
- **Detailed Breakdown**: Shows App Memory, Active, Wired, and Compressed memory with 2 decimal precision
- **Shortened Labels**: Clean, concise display format (A: Active, W: Wired, C: Compressed)
- **Real-time Updates**: Instant refresh when clicking menu bar icon

### 🛠 **Development Enhancements**
- **Cleaned Debug Code**: Removed experimental calculation options, keeping only the working solution
- **Improved Logging**: Essential debug information without clutter
- **Release Optimization**: Built with full compiler optimizations for best performance

## 🚀 **Installation**
1. Quit any existing MemuBar instances
2. Drag `MemuBar.app` to your Applications folder
3. Launch MemuBar from Applications
4. Grant necessary permissions when prompted

## 📋 **System Requirements**
- macOS 15.4 or later
- Apple Silicon (ARM64) or Intel Mac

## 🔍 **What's Next**
This release focuses on accuracy and visual polish. Future updates may include:
- Additional memory metrics
- Customizable refresh intervals
- Export/logging capabilities
- Notification thresholds

---
**Version**: 1.01  
**Build Date**: May 24, 2025  
**Compatibility**: macOS 15.4+ 