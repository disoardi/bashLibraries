#!/usr/bin/env bash

# Source the bash_libraries.sh file using relative path
source ./bash_libraries.sh

# Source the dockerLibs.sh file using relative path
source ./dockerLibs.sh

# Source the logging.sh file using relative path
source ./logging.sh


# Test the functions in bash_libraries.sh file
# Test the fnCheckCMD function
function test_fnCheckCMD() {
    # Test when the command is installed
    fnCheckCMD "echo"
    if [ $? -eq 0 ]; then
        einfo "Test passed: fnCheckCMD for 'echo' command"
    else
        eerror "Test failed: fnCheckCMD for 'echo' command"
    fi

    # Test when the command is not installed
    fnCheckCMD "non_existent_command"
    if [ $? -eq 1 ]; then
        einfo "Test passed: fnCheckCMD for 'non_existent_command'"
    else
        eerror "Test failed: fnCheckCMD for 'non_existent_command'"
    fi
}

# Test the fnWaitYToContinue function
function test_fnWaitYToContinue() {
    # Test when the user enters 'y'
    echo "y" | fnWaitYToContinue
    if [ $? -eq 0 ]; then
        einfo "Test passed: fnWaitYToContinue with 'y' input"
    else
        eerror "Test failed: fnWaitYToContinue with 'y' input"
    fi

    # Test when the user enters 'n'
    echo "n" | fnWaitYToContinue
    if [ $? -eq 1 ]; then
        einfo "Test passed: fnWaitYToContinue with 'n' input"
    else
        eerror "Test failed: fnWaitYToContinue with 'n' input"
    fi
}

# Test the fnPrintIfSet function
function test_fnPrintIfSet() {
    # Test when the variable is set
    MY_VAR="hello"
    fnPrintIfSet "MY_VAR"
    if [ $? -eq 0 ]; then
        einfo "Test passed: fnPrintIfSet with variable set"
    else
        eerror "Test failed: fnPrintIfSet with variable set"
    fi

    # Test when the variable is not set
    unset MY_VAR
    fnPrintIfSet "MY_VAR"
    if [ $? -eq 1 ]; then
        einfo "Test passed: fnPrintIfSet with variable not set"
    else
        eerror "Test failed: fnPrintIfSet with variable not set"
    fi
}

# Test the fnStartSpinner function
function test_fnStartSpinner() {
    # Test starting the spinner
    fnStartSpinner "Testing spinner"
    sleep 2
    fnStopSpinner
    if [ $? -eq 0 ]; then
        einfo "Test passed: fnStartSpinner and fnStopSpinner"
    else
        eerror "Test failed: fnStartSpinner and fnStopSpinner"
    fi
}

# Test the fnSleepProgress function
function test_fnSleepProgress() {
    # Test the sleep progress function
    fnSleepProgress 5
    if [ $? -eq 0 ]; then
        einfo "Test passed: fnSleepProgress"
    else
        eerror "Test failed: fnSleepProgress"
    fi
}

# Test the dockerLibs.sh functions

# Test the fnListServices function
function test_fnListServices() {
    # Test with a valid Docker Compose file
    local services=$(fnListServices "docker-compose.yml")
    if [ $? -eq 0 ]; then
        einfo "Test passed: fnListServices (valid Docker Compose file)"
        einfo "Services: $services"
    else
        eerror "Test failed: fnListServices (valid Docker Compose file)"
    fi

    # Test with an invalid Docker Compose file
    services=$(fnListServices "non-existent-file.yml")
    if [ $? -eq 1 ]; then
        einfo "Test passed: fnListServices (invalid Docker Compose file)"
    else
        eerror "Test failed: fnListServices (invalid Docker Compose file)"
    fi
}

# Test the fnNormalize function
function test_fnNormalize() {
    local input="MyImage123_Test"
    local normalized=$(fnNormalize "$input")
    if [ "$normalized" == "myimage123_test" ]; then
        einfo "Test passed: fnNormalize"
    else
        eerror "Test failed: fnNormalize"
    fi
}

# Test the fnBuildVersion function
function test_fnBuildVersion() {
    # Test building a Docker image with the current branch
    fnBuildVersion "test-image" "-f Dockerfile ."
    if [ $? -eq 0 ]; then
        einfo "Test passed: fnBuildVersion (image built successfully)"
    else
        eerror "Test failed: fnBuildVersion (image build failed)"
    fi
}

# Test the fnBuild function
function test_fnBuild() {
    # Test building a Docker image with a Dockerfile
    fnBuild "Dockerfile"
    if [ $? -eq 0 ]; then
        einfo "Test passed: fnBuild (image built successfully)"
    else
        eerror "Test failed: fnBuild (image build failed)"
    fi
}

# Test the fnBuildImages function
function test_fnBuildImages() {
    # Test building multiple Docker images
    fnBuildImages "Dockerfile" "another-Dockerfile"
    if [ $? -eq 0 ]; then
        einfo "Test passed: fnBuildImages (images built successfully)"
    else
        eerror "Test failed: fnBuildImages (image build failed)"
    fi
}



# Run all the tests
test_fnCheckCMD
test_fnWaitYToContinue
test_fnPrintIfSet
test_fnStartSpinner
test_fnSleepProgress

test_fnListServices
test_fnNormalize
test_fnBuildVersion
test_fnBuild
test_fnBuildImages
