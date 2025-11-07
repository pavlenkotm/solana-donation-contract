cmake_minimum_required(VERSION 3.15)
project(CryptoAlgorithms VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find OpenSSL
find_package(OpenSSL REQUIRED)

# Add executable
add_executable(keccak256 keccak256.cpp)

# Link OpenSSL
target_link_libraries(keccak256 PRIVATE OpenSSL::SSL OpenSSL::Crypto)

# Compiler warnings
if(MSVC)
    target_compile_options(keccak256 PRIVATE /W4)
else()
    target_compile_options(keccak256 PRIVATE -Wall -Wextra -Wpedantic)
endif()

# Install
install(TARGETS keccak256 DESTINATION bin)
