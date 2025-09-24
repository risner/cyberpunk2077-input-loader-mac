Version 1.0

A macOS native implementation of input-loader written in Perl. All macOS systems ship with a version of Perl.

Report issues here and if you know perl and wish to send a PR, I'll check it out.

# Installation

Place `launch_modded.sh` in your game directory. The extrac the `engine` and `r6` directories over your game directory.
Start the game with `launch_modded.sh`.

For reference, the orignal files in `r6/config` have the following checksums:
MD5 (inputContexts_mac.xml) = 60efff8e29829339177585a5e0cab1eb
MD5 (inputUserMappings.xml) = dac2bd1c63fdf4d62d6ff0026a11287a

# Implementation details

This is a reimplementation of Jack Humbert's input-loader written in Perl. All the libraries needed to run this are shipped with modern macOS operating systems.
https://github.com/jackhumbert/cyberpunk2077-input-loader

Requires Redscript 0.5.31 and Game Version 2.31 as a minimum.

# Porting the cpp version to macOS

In testing I ported Jack's original cpp version of input-loader to macOS. But it is a significant change to the code and the CMake files that reimplementing in a native way seems the better approach.

I have shared this here, in case someome wishes to extend the Windows version to also support macOS without RED4ext.

# Where the running binary is stored on disk

```
    uint32_t size = 0;
    _NSGetExecutablePath(nullptr, &size);
    std::vector<char> buf(size);
    if (_NSGetExecutablePath(buf.data(), &size) != 0) {
        throw std::runtime_error("failed to find exe path");
    }
    std::filesystem::canonical(std::string(buf.data()));

    std::string filename(buf.begin(), buf.end());
```

# Makefile for the cpp version (BSD and GNU make)

The first two lines handle GNU make and BSD make (VPATH vs .PATH) respectively.

```
VPATH = ../src        # GNU make search ../src for prerequisites
.PATH: ../src         # BSD make search ../src for prerequisites

CXXFLAGS= -I../deps/spdlog/include/ -I../deps/pugixml/src/ -I../src -std=c++17 -stdlib=libc++
LDFLAGS =
LDLIBS = -lc++ libpugixml.a libspdlog.a

.SUFFIXES: .cpp .o
.cpp.o:
        $(CXX) $(CXXFLAGS) -c $< -o $@

# List of object files to build (one per source file):
OBJS = Utils.o stdafx.o Main.o

all: $(OBJS) inputloader

inputloader: $(OBJS)
        cc -o inputloader $(OBJS) $(LDLIBS)
```
