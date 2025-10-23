# Linux/Mac Setup Guide

## Prerequisites

### Install Ruby 3.2.0
```bash
# Ubuntu/Debian
sudo apt install ruby-full ruby-dev build-essential

# Fedora/RHEL
sudo dnf install ruby ruby-devel gcc make

# macOS
brew install ruby

# Or use rbenv for version management
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/main/bin/rbenv-installer | bash
rbenv install 3.2.0
rbenv global 3.2.0
```

### Install Python 3 (for test file generation)
```bash
# Ubuntu/Debian
sudo apt install python3

# Fedora/RHEL
sudo dnf install python3

# macOS
brew install python3
```

### Install Bundler
```bash
gem install bundler
```

## Quick Start

### 1. Install Dependencies
```bash
./build.sh
```

### 2. Generate Test Files
```bash
# Generate 1GB test file
python3 generate_text_file.py --size-gb 1 --output test_1gb.txt

# Generate 10GB test file
python3 generate_text_file.py --size-gb 10 --output test_10gb.txt
```

### 3. Run the Server
```bash
./run.sh test_1gb.txt
```

### 4. Test the Server
```bash
curl http://localhost:3000/lines/0
curl http://localhost:3000/lines/1000
```

## Performance Tuning

### Configure Puma workers and threads:
```bash
PUMA_WORKERS=2 PUMA_THREADS_MIN=8 PUMA_THREADS_MAX=32 ./run.sh test_10gb.txt
```

### Force parallel indexing:
```bash
USE_PARALLEL_INDEX=1 INDEX_WORKERS=8 ./run.sh test_1gb.txt
```

## Troubleshooting

- **"command not found: ruby"** - Install Ruby following Prerequisites
- **"Permission denied"** - Run `chmod +x *.sh`
- **Port 3000 in use** - Stop other services or change port in run.sh
