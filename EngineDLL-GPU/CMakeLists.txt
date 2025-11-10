cmake_minimum_required(VERSION 3.21)
project(WaveSpecGPU LANGUAGES CXX CUDA)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT DEFINED GPU_CANONICAL_BIN)
    set(GPU_CANONICAL_BIN "${CMAKE_SOURCE_DIR}/Dev/bin" CACHE PATH "Canonical output directory for GPU binaries")
endif()

if(NOT DEFINED GPU_RUNTIME_BIN)
    set(GPU_RUNTIME_BIN "${CMAKE_SOURCE_DIR}/runtime/bin" CACHE PATH "Runtime directory for deployed GPU binaries")
endif()

function(gpu_mirror_target_to_runtime target_name)
    add_custom_command(TARGET ${target_name} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "${GPU_RUNTIME_BIN}"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:${target_name}>"
                "${GPU_RUNTIME_BIN}/$<TARGET_FILE_NAME:${target_name}>"
    )

    get_target_property(_gpu_target_type ${target_name} TYPE)
    if(_gpu_target_type STREQUAL "SHARED_LIBRARY"
       OR _gpu_target_type STREQUAL "STATIC_LIBRARY"
       OR _gpu_target_type STREQUAL "MODULE_LIBRARY")
        add_custom_command(TARGET ${target_name} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "$<TARGET_LINKER_FILE:${target_name}>"
                    "${GPU_RUNTIME_BIN}/$<TARGET_LINKER_FILE_NAME:${target_name}>"
        )
    endif()
endfunction()

set(CLEAN_ROOT "${CMAKE_SOURCE_DIR}/Dev")

add_subdirectory(${CLEAN_ROOT}/src/engine_core src/engine_core)
add_subdirectory(${CLEAN_ROOT}/src/client_ipc src/client_ipc)
add_subdirectory(${CLEAN_ROOT}/src/service src/service)
