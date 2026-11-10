cmake_minimum_required(VERSION 3.16)
project(PROJECT_NAME LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Geant4 REQUIRED ui_all vis_all)
include(${Geant4_USE_FILE})

set(PYTHIA8_DIR "$ENV{HOME}/geant4/pythia8318"
    CACHE PATH "Installation directory of PYTHIA 8")

find_path(PYTHIA8_INCLUDE_DIR
    Pythia8/Pythia.h
    PATHS "${PYTHIA8_DIR}/include"
    REQUIRED)

find_library(PYTHIA8_LIBRARY
    NAMES pythia8
    PATHS "${PYTHIA8_DIR}/lib"
    REQUIRED)

add_executable(PROJECT_NAME src/main.cc)

target_include_directories(PROJECT_NAME PRIVATE
    "${PYTHIA8_INCLUDE_DIR}")

target_link_libraries(PROJECT_NAME PRIVATE
    ${Geant4_LIBRARIES}
    "${PYTHIA8_LIBRARY}")

set_target_properties(PROJECT_NAME PROPERTIES
    BUILD_RPATH "${PYTHIA8_DIR}/lib")
