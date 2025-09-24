Version 1.0 - Alpha Release

A macOS native implementation of input-loader written in Perl. All macOS systems ship with a version of Perl.

Report issues here and if you know perl and wish to send a PR, I'll check it out.

To install, place the `engine` and `r6` directory contents over your game directory. Then run the `inputloader.pl` in `engine/tools`.


----
This is a reimplementation of Jack Humbert's
https://github.com/jackhumbert/cyberpunk2077-input-loader

If someome wishes to extend the Windows version to also support macOS without
RED4ext, you will need code to find the binary's location.

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

I made a very quick port where I cutting out all RED4ext and Windows-ism.
Using a build directory (mac) and this Makefile. Of note this works on both
GNU make and BSD make (VPATH vs .PATH).

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
