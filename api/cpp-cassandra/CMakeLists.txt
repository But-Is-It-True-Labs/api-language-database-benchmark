cmake_minimum_required(VERSION 3.20)

project(
    benchmark_cpp_cassandra
    LANGUAGES C CXX
)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)

set(CASS_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(CASS_BUILD_STATIC ON CACHE BOOL "" FORCE)
set(CASS_USE_STATIC_LIBS ON CACHE BOOL "" FORCE)
set(CASS_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(CASS_BUILD_TESTS OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    cassandra_driver
    GIT_REPOSITORY https://github.com/apache/cassandra-cpp-driver.git
    GIT_TAG 2.17.1
)

FetchContent_MakeAvailable(
    cassandra_driver
)

find_library(
    MICROHTTPD_LIBRARY
    microhttpd
    REQUIRED
)

add_executable(
    benchmark-cpp-cassandra-api
    main.cpp
)

target_include_directories(
    benchmark-cpp-cassandra-api
    PRIVATE
    ${cassandra_driver_SOURCE_DIR}/include
)

target_link_libraries(
    benchmark-cpp-cassandra-api
    PRIVATE
    cassandra_static
    ${MICROHTTPD_LIBRARY}
    pthread
)

target_compile_options(
    benchmark-cpp-cassandra-api
    PRIVATE
    -O3
    -DNDEBUG
)
