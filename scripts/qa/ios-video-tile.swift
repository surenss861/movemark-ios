#!/usr/bin/env swift
//
//  ios-video-tile.swift — tiles simulator recordings side by side (e.g. nav variants A | B | C) at 60 fps.
//
//  Usage: swift scripts/qa/ios-video-tile.swift <out.mov> <label>=<video>@<startSeconds> ...
//  startSeconds aligns the inputs (e.g. each recording's first tab switch, from the frame scan's events).
//

import AVFoundation
import CoreImage
import CoreText
import Foundation

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 3 else { print("usage: ios-video-tile.swift <out.mov> A=a.mov@1.2 B=b.mov@1.3 ..."); exit(2) }
let outURL = URL(fileURLWithPath: args[0])
try? FileManager.default.removeItem(at: outURL)

struct Input { let label: String; let frames: [(Double, CGImage)] }
let panelW = 402, panelH = 874, header = 34, fps = 60.0
let ci = CIContext()
let rgb = CGColorSpaceCreateDeviceRGB()

func load(_ spec: String) throws -> Input {
    let parts = spec.split(separator: "=", maxSplits: 1)
    let rest = parts[1].split(separator: "@")
    let start = rest.count > 1 ? Double(rest[1])! : 0
    let asset = AVURLAsset(url: URL(fileURLWithPath: String(rest[0])))
    let sema = DispatchSemaphore(value: 0)
    var track: AVAssetTrack?
    Task { track = try? await asset.loadTracks(withMediaType: .video).first; sema.signal() }
    sema.wait()
    let reader = try AVAssetReader(asset: asset)
    let out = AVAssetReaderTrackOutput(track: track!, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    reader.add(out); reader.startReading()
    var frames: [(Double, CGImage)] = []
    while let s = out.copyNextSampleBuffer() {
        guard let pb = CMSampleBufferGetImageBuffer(s) else { continue }
        let t = CMSampleBufferGetPresentationTimeStamp(s).seconds - start
        let img = CIImage(cvPixelBuffer: pb)
        let scaled = img.transformed(by: CGAffineTransform(scaleX: CGFloat(panelW) / img.extent.width, y: CGFloat(panelH) / img.extent.height))
        if let cg = ci.createCGImage(scaled, from: scaled.extent) { frames.append((t, cg)) }
    }
    return Input(label: String(parts[0]), frames: frames)
}

let inputs = try args.dropFirst().map(load)
let duration = inputs.map { $0.frames.last!.0 }.min()!
let begin = max(inputs.map { $0.frames.first!.0 }.max()!, -1.0)
let W = panelW * inputs.count, H = panelH + header

let writer = try AVAssetWriter(outputURL: outURL, fileType: .mov)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

func text(_ s: String, _ ctx: CGContext, _ x: CGFloat, _ y: CGFloat) {
    let font = CTFontCreateWithName("Menlo-Bold" as CFString, 18, nil)
    let a = NSAttributedString(string: s, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1)])
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(CTLineCreateWithAttributedString(a), ctx)
}

var cursors = [Int](repeating: 0, count: inputs.count)
var n = 0
var t = begin
while t <= duration {
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
    CVPixelBufferLockBaseAddress(pb!, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb!), width: W, height: H, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb!), space: rgb, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.setFillColor(CGColor(gray: 0.1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    for (k, inp) in inputs.enumerated() {
        while cursors[k] + 1 < inp.frames.count, inp.frames[cursors[k] + 1].0 <= t { cursors[k] += 1 }
        ctx.draw(inp.frames[cursors[k]].1, in: CGRect(x: k * panelW, y: 0, width: panelW, height: panelH))
        text("\(inp.label)  t=\(String(format: "%.2f", t))", ctx, CGFloat(k * panelW + 10), CGFloat(panelH + 9))
    }
    CVPixelBufferUnlockBaseAddress(pb!, [])
    while !input.isReadyForMoreMediaData { usleep(1000) }
    adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(n), timescale: CMTimeScale(fps)))
    n += 1
    t += 1 / fps
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("wrote \(outURL.path): \(n) frames, \(String(format: "%.1f", Double(n) / fps)) s")
