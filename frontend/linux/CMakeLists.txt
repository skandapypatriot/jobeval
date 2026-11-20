cmake_minimum_required(VERSION 3.22)
project(jobeval)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GL REQUIRED gl)
pkg_check_modules(GLIB REQUIRED glib-2.0)
pkg_check_modules(GTK REQUIRED gtk+-3.0)

include_directories(${GL_INCLUDE_DIRS} ${GLIB_INCLUDE_DIRS} ${GTK_INCLUDE_DIRS})

file(GLOB flutter_sources "flutter/*.cpp")
add_library(jobeval SHARED ${flutter_sources})
target_link_libraries(jobeval PRIVATE ${GL_LIBRARIES} ${GLIB_LIBRARIES} ${GTK_LIBRARIES})