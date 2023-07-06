# Reading JPEG 2000 images in iOS

iOS & macOS claim to natively support JPEG 2000, however my experience is that not all JPEG 2000 images are readable; it seems that the Apple implementation of JPEG 2000 is incomplete (at least as of iOS 16/macOS Ventura).

For example, the JPEG 2000 images obtained from certain biometric passports (Spain/Portgual) are readable by other platforms (and tools like Photoshop), but not by iOS & macOS.

To get around this, you can use OpenJPEG to read these "unreadable" images by compiling libopenjp2 as a static library for iOS.

This repo contains a working proof-of-concept iOS app project which also includes a pre-compiled copy of libopenjp2 v2.5.0 compiled for arm64 as a static library, but I've also provided a full step-by-step guide of what I did so you can compile it for yourself and adapt the solution to your requirements:

## Part 1: Compile libopenjp2 for iOS

**1. Download the latest version of OpenJPEG** - Downloads page is [here](https://github.com/uclouvain/openjpeg/releases). Download the source code as a ZIP file and extract.

> At the time of writing (June 2023), the latest version is v2.5.0. You may find these steps don't work with newer versions of OpenJPEG.

**2. Download ios-cmake** - This is a CMake toolchain for Apple platforms (including iOS). You can download the repo or whatever, you just need the file [`ios.toolchain.cmake`](https://github.com/leetal/ios-cmake/blob/master/ios.toolchain.cmake).

> At the time of writing (June 2023), the latest version of ios-cmake is v4.4.0. You may find these steps don't work with newer versions of ios-cmake.

**3. Generate build files**

Use cmake to generate the Xcode build files in the /build folder:

```bash
cd /path/to/openjpeg-2.5.0
mkdir build && cd build
cmake .. -G Xcode -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=path/to/ios.toolchain.cmake -DPLATFORM=OS64 -DBUILD_THIRDPARTY=on -DENABLE_BITCODE=false
```

> This will build for iOS arm64 architecture only. If you want to build for other platforms, change the `-DPLATFORM` argument. [See the ios-cmake docs for more info](https://github.com/leetal/ios-cmake#platform-flag-options--dplatformflag).

**4. Disable NEON (hack)**

You can try and skip to the next stage and build the library directly, but you will likely end up with the following error:

```
Undefined symbols for architecture arm64:
  "_png_init_filter_functions_neon", referenced from:
      _png_read_filter_row in libpng.a(pngrutil.o)
ld: symbol(s) not found for architecture arm64
clang: error: linker command failed with exit code 1 (use -v to see invocation)
```

There's probably an easier way to disabling NEON during the build, but as a quick hack you can modify the file `pngpriv.h` and replace lines 108-134:

```c
#ifndef PNG_ARM_NEON_OPT
   /* ARM NEON optimizations are being controlled by the compiler settings,
    * typically the target FPU.  If the FPU has been set to NEON (-mfpu=neon
    * with GCC) then the compiler will define __ARM_NEON__ and we can rely
    * unconditionally on NEON instructions not crashing, otherwise we must
    * disable use of NEON instructions.
    *
    * NOTE: at present these optimizations depend on 'ALIGNED_MEMORY', so they
    * can only be turned on automatically if that is supported too.  If
    * PNG_ARM_NEON_OPT is set in CPPFLAGS (to >0) then arm/arm_init.c will fail
    * to compile with an appropriate #error if ALIGNED_MEMORY has been turned
    * off.
    *
    * Note that gcc-4.9 defines __ARM_NEON instead of the deprecated
    * __ARM_NEON__, so we check both variants.
    *
    * To disable ARM_NEON optimizations entirely, and skip compiling the
    * associated assembler code, pass --enable-arm-neon=no to configure
    * or put -DPNG_ARM_NEON_OPT=0 in CPPFLAGS.
    */
#  if (defined(__ARM_NEON__) || defined(__ARM_NEON)) && \
   defined(PNG_ALIGNED_MEMORY_SUPPORTED)
#     define PNG_ARM_NEON_OPT 2
#  else
#     define PNG_ARM_NEON_OPT 0
#  endif
#endif
```

with this instead:

```c
#define PNG_ARM_NEON_OPT 0
```

**5. Build the library**

With the above workaround in place, you can now build the libraries:

```bash
cmake --build . --config Release -- CODE_SIGNING_ALLOWED=NO
```

If everything worked, it will end with `** BUILD SUCCEEDED **` and you will now have your build libraries in the `build` folder:

In `build/bin/Release` you will find `libopenjp2.a` (static library) and `libopenjp2.2.5.0.dylib` (dynamic library).

In `build/thirdparty/lib/Release` you will find `liblcms2.a`, `libpng.a`, `libtiff.a` and `libz.a` if you need those.

## Part 2: Add libopenjp2 to your project

I'll explain how to integrate the static library (I've not tried the dynamic library, you can give it a go!)

> These steps are designed for Xcode 14.2, it should work in newer/older versions of Xcode, but the process might be slightly different.

**1. Add libopenjp2.a to your Xcode project** - Take the file from `build/bin/Release/libopenjp2.a` and drag-and-drop it to your Xcode project.

> Ensure that under the "Frameworks, Libraries and Embedded Content" section of your project, you have `libopenjp2.a` listed.

**2. Add the libopenjp2 header files to your Xcode project** - You need to add a bunch of header files from your openjpeg download folder, so that you can call the libopenjp2 functions:

- `src/lib/openjp2/openjpeg.h`
- `src/lib/openjp2/opj_stdint.h`
- `build/src/lib/openjp2/opj_config.h`

**3. Create an Objective-C bridging header for your project** - If your project doesn't have one already, you'll need a bridging header so that you can call (Objective-)C code from Swift. There are a few ways of doing this, but the easiest way is to go to "File > New > File..." in Xcode, create a new "Header File" (call it whatever you want) and when prompted, allow Xcode to create the bridging header for you.

In your bridging header, add:

```c
#import "openjpeg.h"
```

**4. Build your project**

Try and build your Xcode project, it should build successfully.

## Part 3: Decode JPEG 2000 from file

For reasons that will become apparent later, it's much easier to use libopenjp2 to read from a file than from memory, so we'll check that works first and then move on to converting from memory later.

If you don't have one already, you can grab a JPEG 2000 sample image from [here](https://www.dwsamplefiles.com/download-jp2-sample-files/) and add it to your project.

```swift
// Setup a decompressor:

let decompressor = opj_create_decompress(OPJ_CODEC_JP2)
assert(decompressor != nil)

// Setup info/warning/error handlers (optional):

opj_set_info_handler(decompressor, infoHandler, nil)
opj_set_warning_handler(decompressor, warningHandler, nil)
opj_set_error_handler(decompressor, errorHandler, nil)

func infoHandler(msg: UnsafePointer<Int8>?, _: UnsafeMutableRawPointer?) {
    let message = String(cString: msg!)
    print("[Info] ", message)
}

func warningHandler(msg: UnsafePointer<Int8>?, _: UnsafeMutableRawPointer?) {
    let message = String(cString: msg!)
    print("[Warning] ", message)
}

func errorHandler(msg: UnsafePointer<Int8>?, _: UnsafeMutableRawPointer?) {
    let message = String(cString: msg!)
    print("[Error] ", message)
}

// Finish setting up the decompressor:

var params = opj_dparameters_t()
opj_set_default_decoder_parameters(&params)

if (opj_setup_decoder(decompressor, &params) == 0) {
    fatalError("Cannot setup decoder")
}

// Create stream from file:

let path = Bundle.main.path(forResource: "sample1.jp2", ofType: nil)
let stream = opj_stream_create_default_file_stream(path, OPJ_TRUE)

// Create output image:

var opjImage: UnsafeMutablePointer<opj_image_t>? = UnsafeMutablePointer<opj_image_t>.allocate(capacity: 1)

// Read header first into the output image:

if (opj_read_header(stream, decompressor, &opjImage) == 0) {
    fatalError("Failed to read header")
}

// Decode data into the output image:

if (opj_decode(decompressor, stream, opjImage) == 0) {
    fatalError("Failed to decode image")
}

// Cleanup
opj_stream_destroy(stream)
opj_destroy_codec(decompressor)
```

We now have `opjImage` which is a pointer to our image data, but we need to convert this to a CGImage and then to UIImage so we can use it in our app.

## Part 4: Convert `opj_image_t*` to `UIImage`

I found some [old code](https://gist.github.com/nielsbot/1861465#file-uiimagejpeg2000-m-L25) that can handle the conversion of `opj_image_t*` to `CGImageRef` (the conversion of `CGImageRef` to `UIImage` is trivial). The rest of the code is outdated, but CGImage image conversion code still works well.

You will need to make some small modifications to get it to compile, you can find the final versions here:

- [CGImageJPEG2000.h](JPEG2000/CGImageJPEG2000.h)
- [CGImageJPEG2000.m](JPEG2000/CGImageJPEG2000.m)

Don't forget to add it to your bridging header:

```c
#import "CGImageJPEG2000.h"
```

Returning to your Swift code, you can now convert your `opj_image_t*` to `UIImage`:

```swift
let cgImage = CGImageCreateWithJPEG2000Image(opjImage).takeUnretainedValue()
let uiImage = UIImage(cgImage: cgImage)
```

You should verify all this is working before proceeding to the next (final!) stage.

## Part 5: Decode JPEG 2000 from memory

[In the old code in the snippet I posted in the previous part](https://gist.github.com/nielsbot/1861465#file-uiimage-jpeg2000-m-L145), there is the use of a handy function in libopenjp2 called `opj_cio_open` which handles reading from byte buffers in a one-liner. Unfortunately, it seems this functionality was removed in OpenJPEG 2.0, so we're forced to build a stream manually... 😭

Fortunately, [there's a solution to this](https://groups.google.com/g/openjpeg/c/8cebr0u7JgY/m/hc5k6r_LDAAJ) which we can adapt for our use.

The final versions are available here:

- [memory_stream.h](JPEG2000/memory_stream.h)
- [memory_stream.m](JPEG2000/memory_stream.m)

Don't forget to add it to your bridging header:

```c
#import "memory_stream.h"
```

We can now benefit from this higher-level API to create our `opj_image_t*` directly from memory:

```swift
// Read file into Data:
let url = Bundle.main.url(forResource: "sample2.jp2", withExtension: nil)!
let data = try! Data(contentsOf: url)

var mutableData = data // create mutable copy
var opjImage: UnsafeMutablePointer<opj_image_t>?

mutableData.withUnsafeMutableBytes { unsafeBytes in

    let bytes = unsafeBytes.bindMemory(to: UInt8.self).baseAddress!

    // Create the memory stream:
    var memoryStream = opj_memory_stream(pData: bytes, dataSize: data.count, offset: 0)
    let stream = opj_stream_create_default_memory_stream(&memoryStream, OPJ_TRUE)

    opjImage = UnsafeMutablePointer<opj_image_t>.allocate(capacity: 1)

    // Must read header first:
    opj_read_header(stream, decompressor, &opjImage)

    // Decode image:
    if (opj_decode(decompressor, stream, opjImage) == 0) {
        fatalError("Failed to decode image")
    }

    opj_stream_destroy(stream)
}
```

You can now use the code from Step 4 to convert your `opj_image_t*` to `UIImage`.

You can even wrap this functionality into an [extension on `UIImage`](JPEG2000/UIImage+JPEG2000.swift), just like in the sample code.

## Help

#### Your JPEG 2000 image still isn't readable by libopenjp2

Use [Jpylyzer](https://jpylyzer.openpreservation.org/) to verify that your image file is a valid JP2 image.
