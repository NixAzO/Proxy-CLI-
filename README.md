# prx - Video Proxy Generator CLI

Fast video proxy generator with GPU acceleration support. Perfect for video editors who need lightweight proxies for smoother editing.

## Features

- 🚀 **GPU Acceleration** - Auto-detect NVIDIA (NVENC), AMD (AMF), Intel (QSV)
- 📐 **Aspect Ratio Preserved** - No stretching or distortion
- ⏱️ **ETA Display** - Real-time progress with time remaining
- 🎬 **ProRes Support** - Professional codec for DaVinci/Premiere/FCP
- ℹ️ **Video Info** - Check proxy details and software compatibility

## Installation

### Linux / macOS

```bash
# Clone the repo
git clone https://github.com/yourusername/prx.git
cd prx

# Make executable and add to PATH
chmod +x proxy-gen.sh
sudo ln -s $(pwd)/proxy-gen.sh /usr/local/bin/prx
```

Dependencies:
```bash
# Arch Linux
sudo pacman -S ffmpeg bc

# Ubuntu/Debian
sudo apt install ffmpeg bc

# macOS
brew install ffmpeg bc
```

### Windows

1. Install [ffmpeg](https://www.gyan.dev/ffmpeg/builds/) and add to PATH
2. Download `prx.bat` to a folder in your PATH (e.g., `C:\Tools`)
3. Or run directly: `prx.bat video.mp4`

## Usage

```bash
# Single file
prx video.mp4

# Multiple files
prx clip1.mp4 clip2.mov clip3.mkv

# Entire folder
prx ./footage

# With options
prx -q low -c nvenc -o ./proxies ./footage

# Check video info & compatibility
prx -i video_Proxy.mp4
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `-o` | Output directory | `./proxies` |
| `-q` | Quality: `low` \| `medium` \| `high` | `medium` |
| `-s` | Output suffix | `_Proxy` |
| `-c` | Codec: `auto` \| `cpu` \| `nvenc` \| `amf` \| `qsv` \| `prores` | `auto` |
| `-i` | Show video info & compatibility | - |

## Quality Presets

| Quality | Resolution | Use Case |
|---------|------------|----------|
| `low` | 360p | Quick scrubbing, low-end hardware |
| `medium` | 720p | Balanced editing (recommended) |
| `high` | 1080p | Color grading, detailed work |

## Codec Options

| Codec | Description |
|-------|-------------|
| `auto` | Auto-detect best GPU encoder |
| `cpu` | Software encoding (libx264) |
| `nvenc` | NVIDIA GPU |
| `amf` | AMD GPU |
| `qsv` | Intel Quick Sync |
| `prores` | Apple ProRes (best for pro NLEs) |

## Software Compatibility

### H.264 Proxies (default)
✓ DaVinci Resolve, Premiere Pro, Final Cut Pro, After Effects, Kdenlive, Shotcut

### ProRes Proxies
✓ DaVinci Resolve, Premiere Pro, Final Cut Pro, After Effects  
△ Kdenlive (requires codec installation)

## Examples

```bash
# Fast proxy with NVIDIA GPU
prx -c nvenc -q low ./raw_footage

# ProRes for professional workflow
prx -c prores -q medium -o ./proxies ./footage

# Check what you created
prx -i ./proxies/video_Proxy.mp4
```

## License

MIT
