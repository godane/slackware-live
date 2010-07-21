cmake_minimum_required(VERSION 2.4)

set (PROJECT_NAME "slackware-live")
project (${PROJECT_NAME})
set (PROJECT_VERSION "0.2.8")

add_subdirectory (scripts)
add_subdirectory (linomad)
install (DIRECTORY doc/ DESTINATION doc/${PROJECT_NAME}-${PROJECT_VERSION})
