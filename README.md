# BetterPortrait

A lightweight macOS app that batch-processes portrait photos — detect faces, crop uniformly, remove backgrounds, and export. Built for when speakers submit inconsistent portrait photos and you need them all to look uniform.

## Features

- **Face Detection** — Automatically detects faces using Apple's Vision framework
- **Uniform Cropping** — All photos are cropped so faces appear at a consistent size and position
- **Background Removal** — Person segmentation removes the original background and replaces it with a solid color of your choice
- **Batch Processing** — Import dozens of photos and process them all at once
- **Multiple Aspect Ratios** — Choose from 1:1, 3:4, 9:16, 4:3, or 16:9
- **Two Sizing Modes**
  - *Best Fit* — Faces are approximately similar size with better framing
  - *Match Largest* — All faces are exactly the same size, driven by the largest face
- **No External Dependencies** — Uses only Apple frameworks (Vision, Core Graphics, Core Image)

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26 or later

## Getting Started

1. Clone the repo
2. Open `BetterPortrait/BetterPortrait.xcodeproj` in Xcode
3. Build and run (Cmd+R)

## Usage

1. **Import** — Drag and drop photos onto the main area, or click "Choose Files"
2. **Configure** — Use the left sidebar to select crop ratio, background color, and sizing mode
3. **Process** — Click the green "Process" button in the bottom-right panel
4. **Export** — Click "Export" and choose "Export All" or "Export Processed Only"

Photos where no face is detected are left untouched and marked with a warning.

## Built With

- SwiftUI
- Vision framework (`VNDetectFaceRectanglesRequest`, `VNGeneratePersonSegmentationRequest`)
- Core Image (`CIBlendWithMask` for compositing)
- Core Graphics

## Author

**Haochen Zeng** — [@hzeng412](https://x.com/hzeng412)

## License

MIT
