//
//  UIImage+JPEG2000.swift
//  JPEG2000
//
//  Created by Jonathan Ellis on 19/06/2023.
//

import Foundation
import UIKit

func infoHandler(msg: UnsafePointer<Int8>?, user_data: UnsafeMutableRawPointer?) {
    let message = String(cString: msg!)
    print("[Info] ", message)
}

func warningHandler(msg: UnsafePointer<Int8>?, user_data: UnsafeMutableRawPointer?) {
    let message = String(cString: msg!)
    print("[Warning] ", message)
}

func errorHandler(msg: UnsafePointer<Int8>?, user_data: UnsafeMutableRawPointer?) {
    let message = String(cString: msg!)
    print("[Error] ", message)
}

extension UIImage {

    public convenience init(jpeg2000Data data: Data) {
        // Create JP2 decompressor:
        let decompressor = opj_create_decompress(OPJ_CODEC_JP2)
        if (decompressor == nil) {
            fatalError("Failed to create decompressor")
        }

        // Setup info/warning/error handlers (optional):
        opj_set_info_handler(decompressor, infoHandler, nil)
        opj_set_warning_handler(decompressor, warningHandler, nil)
        opj_set_error_handler(decompressor, errorHandler, nil)

        // Set default params:
        var params = opj_dparameters_t()
        opj_set_default_decoder_parameters(&params)

        if (opj_setup_decoder(decompressor, &params) == 0) {
            fatalError("Cannot setup decoder")
        }

        var mutableData = data
        var opjImage: UnsafeMutablePointer<opj_image_t>?

        mutableData.withUnsafeMutableBytes { unsafeBytes in

            let bytes = unsafeBytes.bindMemory(to: UInt8.self).baseAddress!

            // cio functions were removed in newer versions of libopenjp2, so need to do this ourselves:
            var memoryStream = opj_memory_stream(pData: bytes, dataSize: data.count, offset: 0)
            let stream = opj_stream_create_default_memory_stream(&memoryStream, OPJ_TRUE)

            opjImage = UnsafeMutablePointer<opj_image_t>.allocate(capacity: 1)

            // Must read header first:
            if (opj_read_header(stream, decompressor, &opjImage) == 0) {
                fatalError("Failed to read header")
            }

            // Decode image:
            if (opj_decode(decompressor, stream, opjImage) == 0) {
                fatalError("Failed to decode image")
            }

            opj_stream_destroy(stream)
        }

        opj_destroy_codec(decompressor)

        // Convert to CGImage and then to UIImage
        let im = CGImageCreateWithJPEG2000Image(opjImage).takeUnretainedValue()
        self.init(cgImage: im)
    }

}
