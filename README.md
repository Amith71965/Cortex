# Cortex - iOS CoreML Application

A sophisticated iOS application leveraging CoreML with DistilBERT model for advanced machine learning capabilities on-device.

## Features

- **On-Device ML Processing**: Uses DistilBERT CoreML model for fast, private inference
- **Modern iOS Architecture**: Built with SwiftUI and MVVM architecture
- **Optimized Performance**: 132 MB CoreML model optimized for iOS devices
- **Privacy-First**: All processing happens locally on the device

## Project Structure

```
Cortex/
├── Cortex/                    # Main application code
├── Cortex.xcodeproj/          # Xcode project configuration
├── CortexTests/               # Unit tests
├── CortexUITests/             # UI tests
├── Models/                    # CoreML models
│   └── distilbert-base.mlpackage/  # DistilBERT model (download from Releases)
├── Services/                  # Business logic and API services
├── ViewModels/                # MVVM ViewModels
├── Views/                     # SwiftUI Views
└── Utils/                     # Utility functions
```

## Requirements

- **iOS**: 14.0 or later
- **Xcode**: 13.0 or later
- **Swift**: 5.5 or later
- **RAM**: Minimum 2GB (4GB recommended for best performance)
- **Storage**: ~300MB free space

## Installation & Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/Amith7965/Cortex.git
cd Cortex
```

### Step 2: Download the CoreML Model

The DistilBERT CoreML model is hosted in GitHub Releases due to its size (132 MB).

**Option A: Manual Download**
1. Go to the [Releases page](https://github.com/Amith71965/Cortex/releases/tag/v1.0.0)
2. Download the `distilbert-base.mlpackage` from the latest release
3. Extract and place it in: `Cortex/Models/distilbert-base.mlpackage/`

**Option B: Using Terminal**
```bash
# Download the model from releases
cd Cortex/Models/
# Download your release asset here
# Then extract if it's zipped
unzip distilbert-base.mlpackage.zip
```

### Step 3: Install Dependencies (If using CocoaPods)

```bash
pod install
```

If you're not using CocoaPods, skip this step.

### Step 4: Open in Xcode

```bash
# If using CocoaPods
open Cortex.xcworkspace

# Or if not using CocoaPods
open Cortex.xcodeproj
```

### Step 5: Configure Build Settings (if needed)

1. Select the **Cortex** project in Xcode
2. Select the **Cortex** target
3. Go to **Build Settings**
4. Search for "CoreML" to verify CoreML framework is linked
5. Ensure **Minimum Deployment Target** is set to iOS 14.0 or later

## Running the Application

### Method 1: Using Xcode GUI

1. Open Cortex in Xcode
2. Select your target device/simulator from the top toolbar
3. Press `Cmd + R` or click the **Play** button
4. Wait for the build to complete
5. The app will launch on your device/simulator


### Method 2: Building for Physical Device

1. Connect your iPhone via USB
2. In Xcode, select your device from the device picker
3. Press `Cmd + R` to build and run
4. Trust the developer certificate on your device if prompted

## Building a Release Version

```bash
# Build for Release
xcodebuild -workspace Cortex.xcworkspace -scheme Cortex -configuration Release -destination generic/platform=iOS | xcpretty
```

## CoreML Model Details

**Model Name**: DistilBERT Base  
**Size**: 132 MB  
**Type**: Text Classification/NLP  
**Location**: `Cortex/Models/distilbert-base.mlpackage/`  
**Source**: [GitHub Releases](https://github.com/Amith71965/Cortex/releases/tag/v1.0.0)

The model is optimized for iOS and runs efficiently on-device without requiring internet connectivity.

## Development

### Running Tests

```bash
# Run all tests
xcodebuild -workspace Cortex.xcworkspace -scheme Cortex -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' test | xcpretty

# Run specific test suite
xcodebuild -workspace Cortex.xcworkspace -scheme CortexTests -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' test | xcpretty
```

## Troubleshooting

### Issue: "Model not found" error

**Solution**: 
1. Ensure the `.mlpackage` file is in `Cortex/Models/distilbert-base.mlpackage/`
2. In Xcode, select Cortex target
3. Go to Build Phases
4. Expand "Copy Bundle Resources"
5. If missing, drag `distilbert-base.mlpackage` from Finder

### Issue: Slow performance on device

**Solution**: 
- Reduce batch size for model inference
- Profile using Xcode's Instruments (Debug > Profiler)
- Consider model quantization if available

### Issue: Cannot find distilbert-base.mlpackage

**Solution**: Download it from [GitHub Releases](https://github.com/Amith71965/Cortex/releases/tag/v1.0.0) and place in `Cortex/Models/`

## Performance Optimization

- Model inference runs on Neural Engine when available (A12 Bionic or later)
- All processing is done locally without network calls
- Typical inference time: 100-500ms depending on input size

## Privacy & Security

- ✅ No data leaves the device
- ✅ All processing happens locally
- ✅ No telemetry or tracking
- ✅ Model weights are not exposed to users

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

**Amith Kumar Yadav K**  
Computer Science from Boston University  
Passionate about AI and Machine Learning

- GitHub: [@Amith7965](https://github.com/Amith7965)
- Email: svnitbos@bu.edu

## Support

For issues, questions, or suggestions, please open an [Issue](https://github.com/Amith71965/Cortex/issues) on GitHub.

## Acknowledgments

- DistilBERT model by Hugging Face
- CoreML documentation from Apple
- Community feedback and contributions
