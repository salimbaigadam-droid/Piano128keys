cmake_minimum_required(VERSION 3.15)
project(PianoCppBackend)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(Threads REQUIRED)

# Include directories
include_directories(${CMAKE_SOURCE_DIR}/include)

# Add executable
add_executable(piano_cpp_backend cpp_backend.cpp)

# Link libraries
target_link_libraries(piano_cpp_backend
    Threads::Threads
    pqxx
    pq
)

# External dependencies (you'll need to install these)
# libpqxx - PostgreSQL C++ library
# cpp-httplib - HTTP server library  
# nlohmann-json - JSON parsing

# Installation instructions:
# Ubuntu/Debian:
#   sudo apt-get install libpqxx-dev nlohmann-json3-dev
#
# macOS:
#   brew install libpqxx nlohmann-json
#
# Then download cpp-httplib:
#   wget https://raw.githubusercontent.com/yhirose/cpp-httplib/master/httplib.h -P include/

# Build instructions:
#   mkdir build && cd build
#   cmake ..
#   make
#   ./piano_cpp_backend

# Compiler flags for optimization
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -march=native")

# Enable warnings
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wpedantic")
endif()

# Optional: Add tests
# enable_testing()
# add_subdirectory(tests)
