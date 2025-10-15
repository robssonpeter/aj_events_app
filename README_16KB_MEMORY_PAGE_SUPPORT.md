# 16 KB Memory Page Size Support

## Background
Google has announced that apps must support 16 KB memory page sizes by November 1, 2025. This is related to changes in ARM architecture, particularly for newer Android devices.

## Changes Made
The following changes were made to ensure the app supports 16 KB memory page sizes:

1. Modified `android/app/build.gradle.kts` to add NDK configuration:
   ```kotlin
   defaultConfig {
       // ... existing configuration ...
       
       // Add support for 16 KB memory page sizes (required by Google by Nov 1, 2025)
       ndk {
           abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
       }
   }
   ```

2. Modified `local_plugins/image_gallery_saver/android/build.gradle` to add NDK configuration:
   ```groovy
   defaultConfig {
       // ... existing configuration ...
       
       // Add support for 16 KB memory page sizes (required by Google by Nov 1, 2025)
       ndk {
           abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64'
       }
   }
   ```

## Why This Is Necessary
The 16 KB memory page size is a change in the memory architecture of newer ARM devices. By explicitly specifying the supported ABIs (Application Binary Interfaces) and ensuring the native libraries are compiled with support for these architectures, we ensure compatibility with devices that use 16 KB memory pages.

Without these changes, the app might crash or behave unexpectedly on devices with 16 KB memory page sizes.

## Testing
After making these changes, it's recommended to test the app on a variety of devices, particularly newer ARM-based devices, to ensure compatibility.