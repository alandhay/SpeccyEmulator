#!/bin/bash

# ZX Spectrum Emulator Setup Script
# Installs all required dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎮 ZX Spectrum Emulator Setup${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update package list
echo -e "${BLUE}Updating package list...${NC}"
sudo apt-get update

# Install system dependencies
echo -e "${BLUE}Installing system dependencies...${NC}"

# Install FUSE emulator
if ! command_exists fuse; then
    echo -e "${YELLOW}Installing FUSE emulator...${NC}"
    sudo apt-get install -y fuse-emulator-sdl fuse-emulator-common
else
    echo -e "${GREEN}✅ FUSE emulator already installed${NC}"
fi

# Install FFmpeg
if ! command_exists ffmpeg; then
    echo -e "${YELLOW}Installing FFmpeg...${NC}"
    sudo apt-get install -y ffmpeg
else
    echo -e "${GREEN}✅ FFmpeg already installed${NC}"
fi

# Install Python3 and pip
if ! command_exists python3; then
    echo -e "${YELLOW}Installing Python3...${NC}"
    sudo apt-get install -y python3 python3-pip python3-venv
else
    echo -e "${GREEN}✅ Python3 already installed${NC}"
fi

# Install additional tools
echo -e "${YELLOW}Installing additional tools...${NC}"
sudo apt-get install -y \
    imagemagick \
    x11-utils \
    lsof \
    curl \
    wget

# Install X11 if not present (for headless systems)
if ! command_exists startx; then
    echo -e "${YELLOW}Installing X11 server...${NC}"
    sudo apt-get install -y \
        xorg \
        xserver-xorg \
        x11-xserver-utils \
        xinit
fi

# Create Python virtual environment
echo -e "${BLUE}Setting up Python virtual environment...${NC}"
cd "$PROJECT_ROOT"

if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "${GREEN}✅ Virtual environment created${NC}"
else
    echo -e "${GREEN}✅ Virtual environment already exists${NC}"
fi

# Activate virtual environment and install Python packages
source venv/bin/activate
echo -e "${BLUE}Installing Python packages...${NC}"
pip install --upgrade pip
pip install -r server/requirements.txt

# Create necessary directories
echo -e "${BLUE}Creating project directories...${NC}"
mkdir -p logs
mkdir -p stream/hls
mkdir -p games

# Download sample games (optional)
echo -e "${BLUE}Setting up sample games...${NC}"
cd games

# Create some placeholder game files
cat > README.txt << EOF
ZX Spectrum Games Directory

Place your .tzx, .tap, .z80, or .sna game files here.

You can download games from:
- World of Spectrum: https://worldofspectrum.org/
- Spectrum Computing: https://spectrumcomputing.co.uk/

Popular games to try:
- Manic Miner
- Jet Set Willy
- Chuckie Egg
- Horace Goes Skiing
- Knight Lore
- Sabre Wulf
EOF

# Set up X11 configuration for headless systems
echo -e "${BLUE}Configuring X11...${NC}"
if [ ! -f "/etc/X11/xorg.conf" ] && [ -z "$DISPLAY" ]; then
    echo -e "${YELLOW}Setting up virtual display for headless operation...${NC}"
    
    # Install Xvfb for virtual display
    sudo apt-get install -y xvfb
    
    # Create a simple X11 startup script
    cat > "$PROJECT_ROOT/scripts/start-x11.sh" << 'EOF'
#!/bin/bash
# Start virtual X11 display
export DISPLAY=:99
Xvfb :99 -screen 0 1024x768x24 &
XVFB_PID=$!
echo $XVFB_PID > /tmp/xvfb.pid
echo "Virtual display started on :99"
EOF
    
    chmod +x "$PROJECT_ROOT/scripts/start-x11.sh"
fi

# Create desktop shortcut (if desktop environment is available)
if [ -d "$HOME/Desktop" ]; then
    echo -e "${BLUE}Creating desktop shortcut...${NC}"
    cat > "$HOME/Desktop/ZX-Spectrum-Emulator.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=ZX Spectrum Emulator
Comment=Web-based ZX Spectrum Emulator
Exec=$PROJECT_ROOT/scripts/start-emulator.sh
Icon=applications-games
Terminal=true
Categories=Game;Emulator;
EOF
    chmod +x "$HOME/Desktop/ZX-Spectrum-Emulator.desktop"
fi

# Final checks
echo -e "${BLUE}Running final checks...${NC}"

# Check FUSE installation
if fuse --help >/dev/null 2>&1; then
    echo -e "${GREEN}✅ FUSE emulator working${NC}"
else
    echo -e "${RED}❌ FUSE emulator installation failed${NC}"
fi

# Check FFmpeg installation
if ffmpeg -version >/dev/null 2>&1; then
    echo -e "${GREEN}✅ FFmpeg working${NC}"
else
    echo -e "${RED}❌ FFmpeg installation failed${NC}"
fi

# Check Python environment
cd "$PROJECT_ROOT"
source venv/bin/activate
if python3 -c "import websockets, aiohttp, PIL" 2>/dev/null; then
    echo -e "${GREEN}✅ Python dependencies working${NC}"
else
    echo -e "${RED}❌ Python dependencies installation failed${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Setup complete!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Run: ./scripts/start-emulator.sh"
echo "2. Open http://localhost:8080 in your browser"
echo "3. Click 'Start Emulator' to begin"
echo ""
echo -e "${YELLOW}Note:${NC} If you're on a headless system, run ./scripts/start-x11.sh first"
echo ""
