cmake_minimum_required(VERSION 3.20)
project(benchmark_cpp_api LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_BUILD_TYPE Release)

find_path(MARIADB_INCLUDE_DIR mysql/mysql.h REQUIRED)
find_library(MARIADB_LIBRARY mariadb REQUIRED)
find_library(MICROHTTPD_LIBRARY microhttpd REQUIRED)

add_executable(benchmark-cpp-api main.cpp)

target_include_directories(benchmark-cpp-api PRIVATE ${MARIADB_INCLUDE_DIR})
target_link_libraries(benchmark-cpp-api PRIVATE ${MARIADB_LIBRARY} ${MICROHTTPD_LIBRARY} pthread)
target_compile_options(benchmark-cpp-api PRIVATE -O3 -DNDEBUG)
