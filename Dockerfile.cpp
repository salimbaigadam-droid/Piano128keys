FROM ubuntu:22.04

WORKDIR /app

# Install build dependencies and libraries
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libpqxx-dev \
    nlohmann-json3-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Download cpp-httplib
RUN mkdir -p include && \
    wget https://raw.githubusercontent.com/yhirose/cpp-httplib/master/httplib.h -O include/httplib.h

# Copy source files
COPY cpp_backend.cpp .
COPY CMakeLists.txt .

# Build the application
RUN mkdir build && cd build && \
    cmake .. && \
    make

# Expose port
EXPOSE 8002

# Run the application
CMD ["./build/piano_cpp_backend"]
