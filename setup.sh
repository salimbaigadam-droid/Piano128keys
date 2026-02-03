#!/bin/bash

# 128-Key Piano Application Setup Script
# This script sets up the entire application stack

set -e  # Exit on error

echo "🎹 128-Key Professional Piano Application Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if Docker is installed
check_docker() {
    echo "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        echo "Please install Docker from https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        echo "Please install Docker Compose from https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    print_status "Docker and Docker Compose are installed"
}

# Setup using Docker
setup_docker() {
    echo ""
    echo "Setting up with Docker..."
    
    # Stop any existing containers
    if docker-compose ps &> /dev/null; then
        print_warning "Stopping existing containers..."
        docker-compose down
    fi
    
    # Build and start containers
    print_status "Building containers (this may take a few minutes)..."
    docker-compose build
    
    print_status "Starting services..."
    docker-compose up -d
    
    # Wait for database to be ready
    echo "Waiting for database to initialize..."
    sleep 10
    
    # Check if services are running
    if docker-compose ps | grep -q "Up"; then
        print_status "All services are running!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎉 Setup Complete!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Service URLs:"
        echo "  Frontend:       http://localhost:3000"
        echo "  Python API:     http://localhost:8001"
        echo "  C++ API:        http://localhost:8002"
        echo "  Rust API:       http://localhost:8003"
        echo "  PostgreSQL:     localhost:5432"
        echo ""
        echo "Test the backends:"
        echo "  curl http://localhost:8001/api/python/health"
        echo "  curl http://localhost:8002/api/cpp/health"
        echo "  curl http://localhost:8003/api/rust/health"
        echo ""
        echo "View logs:"
        echo "  docker-compose logs -f"
        echo ""
        echo "Stop services:"
        echo "  docker-compose down"
        echo ""
    else
        print_error "Some services failed to start"
        echo "Check logs with: docker-compose logs"
        exit 1
    fi
}

# Setup manually
setup_manual() {
    echo ""
    echo "Manual setup selected. Please ensure you have:"
    echo "  1. PostgreSQL installed and running"
    echo "  2. Python 3.11+ with pip"
    echo "  3. C++ compiler with CMake"
    echo "  4. Rust toolchain"
    echo "  5. Node.js 18+ with npm"
    echo ""
    
    read -p "Continue with manual setup? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Setup cancelled"
        exit 0
    fi
    
    # Database setup
    echo ""
    echo "Setting up database..."
    read -p "Database name (default: piano_db): " db_name
    db_name=${db_name:-piano_db}
    read -p "Database user (default: piano_user): " db_user
    db_user=${db_user:-piano_user}
    read -s -p "Database password: " db_pass
    echo ""
    
    echo "Creating database..."
    sudo -u postgres psql -c "CREATE DATABASE $db_name;" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE USER $db_user WITH PASSWORD '$db_pass';" 2>/dev/null || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;"
    
    print_status "Database created"
    
    # Initialize schema
    echo "Initializing database schema..."
    PGPASSWORD=$db_pass psql -U $db_user -d $db_name -f database_schema.sql
    print_status "Database schema initialized"
    
    # Python backend
    echo ""
    echo "Setting up Python backend..."
    if command -v python3 &> /dev/null; then
        python3 -m pip install -r requirements.txt
        print_status "Python dependencies installed"
    else
        print_warning "Python 3 not found. Please install dependencies manually:"
        echo "  pip install -r requirements.txt"
    fi
    
    # Frontend
    echo ""
    echo "Setting up frontend..."
    if command -v npm &> /dev/null; then
        npm install
        print_status "Frontend dependencies installed"
    else
        print_warning "npm not found. Please install dependencies manually:"
        echo "  npm install"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 Manual Setup Instructions"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Start Python backend:"
    echo "   python python_backend.py"
    echo ""
    echo "2. Build and start C++ backend:"
    echo "   mkdir build && cd build && cmake .. && make"
    echo "   ./piano_cpp_backend"
    echo ""
    echo "3. Build and start Rust backend:"
    echo "   cargo build --release"
    echo "   cargo run --release"
    echo ""
    echo "4. Start frontend:"
    echo "   npm run dev"
    echo ""
}

# Main menu
echo ""
echo "Choose setup method:"
echo "  1) Docker (recommended)"
echo "  2) Manual setup"
echo ""
read -p "Enter choice (1 or 2): " choice

case $choice in
    1)
        check_docker
        setup_docker
        ;;
    2)
        setup_manual
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "For more information, see README.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
