set(BIN_DIR "${GPU_CANONICAL_BIN}")
if(NOT IS_ABSOLUTE "${BIN_DIR}")
    set(BIN_DIR "${CMAKE_SOURCE_DIR}/${BIN_DIR}")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(GpuEngineService
    src/main.cpp
    src/Service.cpp
    src/PipeServer.cpp
)

target_include_directories(GpuEngineService
    PRIVATE
        ${CLEAN_ROOT}/Include/service
        ${CLEAN_ROOT}/Include/ipc
        ${CLEAN_ROOT}/Include/engine_core
)

target_link_libraries(GpuEngineService PRIVATE GpuEngine)

set_target_properties(GpuEngineService PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${BIN_DIR}"
    EXPORT_COMPILE_COMMANDS ON)

foreach(cfg IN ITEMS Debug Release RelWithDebInfo MinSizeRel)
    string(TOUPPER "${cfg}" cfg_upper)
    set_target_properties(GpuEngineService PROPERTIES
        "RUNTIME_OUTPUT_DIRECTORY_${cfg_upper}" "${BIN_DIR}"
    )
endforeach()

gpu_mirror_target_to_runtime(GpuEngineService)
