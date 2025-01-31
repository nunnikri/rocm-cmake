# ######################################################################################################################
# Copyright (C) 2022 Advanced Micro Devices, Inc.
# ######################################################################################################################

set(ROCM_WRAPPER_TEMPLATE_HEADER "${CMAKE_CURRENT_LIST_DIR}/header_template.h.in"
    CACHE INTERNAL "Path to wrapper header file template.")

function(rocm_wrap_header_dir DIRECTORY)
    set(options )
    set(oneValueArgs HEADER_LOCATION INCLUDE_LOCATION)
    set(multiValueArgs PATTERNS GUARDS WRAPPER_LOCATIONS OUTPUT_LOCATIONS)
    cmake_parse_arguments(PARSE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    if(NOT PARSE_HEADER_LOCATION)
        set(PARSE_HEADER_LOCATION "include/${CMAKE_PROJECT_NAME}")
    endif()
    if(NOT PARSE_INCLUDE_LOCATION)
        set(PARSE_INCLUDE_LOCATION "include")
    endif()
    if(NOT PARSE_PATTERNS)
        set(PARSE_PATTERNS "*.h;*.hpp;*.hh;*.hxx;*.inl")
    endif()
    foreach(PATTERN IN LISTS PARSE_PATTERNS)
        list(APPEND QUALIFIED_PATTERNS "${DIRECTORY}/${PATTERN}")
    endforeach()
    file (GLOB_RECURSE include_files RELATIVE "${DIRECTORY}" ${QUALIFIED_PATTERNS})
    foreach (include_file ${include_files})
        rocm_wrap_header_file(
            ${include_file}
            GUARDS ${PARSE_GUARDS}
            HEADER_LOCATION ${PARSE_HEADER_LOCATION}
            INCLUDE_LOCATION ${PARSE_INCLUDE_LOCATION}
            WRAPPER_LOCATIONS ${PARSE_WRAPPER_LOCATIONS}
            OUTPUT_LOCATIONS ${PARSE_OUTPUT_LOCATIONS}
        )
    endforeach()
endfunction()

function(rocm_wrap_header_file)
    set(options )
    set(oneValueArgs HEADER_LOCATION INCLUDE_LOCATION)
    set(multiValueArgs GUARDS WRAPPER_LOCATIONS OUTPUT_LOCATIONS HEADERS)
    cmake_parse_arguments(PARSE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    set(PARSE_HEADERS ${PARSE_HEADERS} ${PARSE_UNPARSED_ARGUMENTS})
    if(NOT PARSE_HEADER_LOCATION)
        set(PARSE_HEADER_LOCATION "include/${CMAKE_PROJECT_NAME}")
    endif()
    if(NOT PARSE_INCLUDE_LOCATION)
        set(PARSE_INCLUDE_LOCATION "include")
    endif()
    foreach(INCLUDE_FILE IN LISTS PARSE_HEADERS)
        set(GUARD_LIST ${PARSE_GUARDS})
        set(WRAPPER_LOC_LIST ${PARSE_WRAPPER_LOCATIONS})
        set(OUTPUT_LOC_LIST ${PARSE_OUTPUT_LOCATIONS})
        if(CPACK_PACKAGING_INSTALL_PREFIX)
            set(HEADER_INSTALL_PREFIX "${CPACK_PACKAGING_INSTALL_PREFIX}")
        else()
            set(HEADER_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")
        endif()
        get_filename_component(header_location "${PARSE_HEADER_LOCATION}/${INCLUDE_FILE}"
            ABSOLUTE BASE_DIR "${HEADER_INSTALL_PREFIX}")
        get_filename_component(file_name ${INCLUDE_FILE} NAME)
        get_filename_component(file_path ${INCLUDE_FILE} DIRECTORY)
        file(RELATIVE_PATH correct_include "${HEADER_INSTALL_PREFIX}/${PARSE_INCLUDE_LOCATION}" "${header_location}")
        string(REPLACE "/" ";" path_dirs "${file_path}")

        set(guard_common "")
        foreach(subdir IN LISTS path_dirs)
            if(NOT (subdir STREQUAL '' OR subdir STREQUAL '.'))
                string(TOUPPER ${subdir} subdir_uc)
                set(guard_common "${guard_common}_${subdir_uc}")
            endif()
        endforeach()
        string(REGEX REPLACE "[^A-Za-z0-9_]" "_" guard_common "${guard_common}_${file_name}")
        string(TOUPPER ${guard_common} guard_common)

        # do-while
        set(first_time true)
        while(first_time OR GUARD_LIST OR WRAPPER_LOC_LIST OR OUTPUT_LOC_LIST)
            rocm_wrap_header_get_info(ITEM GUARD_LIST WRAPPER_LOC_LIST OUTPUT_LOC_LIST)
            set(include_guard "ROCM_${ITEM_GUARD}${guard_common}")
            set(wrapper_location "${ITEM_WRAPPER_LOCATION}/${file_path}")
            file(RELATIVE_PATH file_rel_path "${wrapper_location}" "${header_location}")
            configure_file(
                "${ROCM_WRAPPER_TEMPLATE_HEADER}"
                "${ITEM_OUTPUT_LOCATION}/${INCLUDE_FILE}"
            )
            set(first_time false)
        endwhile()
    endforeach()
endfunction()

# internal
macro(rocm_wrap_header_get_info OUTPUT_PREFIX GUARDS_LIST WRAPPER_LOC_LIST OUTPUT_LOC_LIST)
    if(${GUARDS_LIST})
        list(GET ${GUARDS_LIST} 0 ${OUTPUT_PREFIX}_GUARD)
        list(REMOVE_AT ${GUARDS_LIST} 0)
    else()
        set(${OUTPUT_PREFIX}_GUARD WRAPPER)
    endif()
    if(${WRAPPER_LOC_LIST})
        list(GET ${WRAPPER_LOC_LIST} 0 ${OUTPUT_PREFIX}_WRAPPER_LOCATION)
        list(REMOVE_AT ${WRAPPER_LOC_LIST} 0)
    else()
        set(${OUTPUT_PREFIX}_WRAPPER_LOCATION "${CMAKE_PROJECT_NAME}/include")
    endif()
    if(${OUTPUT_LOC_LIST})
        list(GET ${OUTPUT_LOC_LIST} 0 ${OUTPUT_PREFIX}_OUTPUT_LOCATION)
        list(REMOVE_AT ${OUTPUT_LOC_LIST} 0)
    else()
        set(${OUTPUT_PREFIX}_OUTPUT_LOCATION ${CMAKE_BINARY_DIR}/${${OUTPUT_PREFIX}_WRAPPER_LOCATION})
    endif()
    get_filename_component(${OUTPUT_PREFIX}_WRAPPER_LOCATION "${${OUTPUT_PREFIX}_WRAPPER_LOCATION}"
        ABSOLUTE BASE_DIR "${HEADER_INSTALL_PREFIX}")
    get_filename_component(${OUTPUT_PREFIX}_OUTPUT_LOCATION "${${OUTPUT_PREFIX}_OUTPUT_LOCATION}"
        ABSOLUTE BASE_DIR "${PROJECT_BINARY_DIR}")
endmacro()
