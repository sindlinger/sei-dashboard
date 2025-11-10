cmake_minimum_required(VERSION 3.21)
project(GpuWaveViz LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT WIN32)
    message(WARNING "GpuBridge DLL is intended for Windows MetaTrader deployments.")
endif()

add_library(GpuWaveViz SHARED
    WaveVizExports.cpp
    WaveVizContext.cpp
    GpuLogger.cpp
    GpuStatus.cpp
)

if(WIN32)
    target_sources(GpuWaveViz PRIVATE dllmain.cpp)
endif()

target_include_directories(GpuWaveViz PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

find_package(CUDAToolkit REQUIRED)

target_link_libraries(GpuWaveViz PRIVATE CUDA::cufft)

set_target_properties(GpuWaveViz PROPERTIES
    CUDA_SEPARABLE_COMPILATION ON
    CUDA_ARCHITECTURES 86
    CUDA_RUNTIME_LIBRARY Shared
    WINDOWS_EXPORT_ALL_SYMBOLS OFF
    OUTPUT_NAME "GpuWaveViz"
)

target_sources(GpuWaveViz PRIVATE
    WaveVizKernels.cu
)
