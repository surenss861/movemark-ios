#!/usr/bin/env swift
//
//  ios-nav-frame-scan.swift — flags root-tab switch frames that show what 1.4.1 must never show.
//
//  Usage:  swift scripts/qa/ios-nav-frame-scan.swift <video.mov> <out-dir> [--label NAME]
//
//  A helper, not proof: it narrows thousands of frames to the ones a person must look at. Human review of the
//  contact sheets and the real-iPhone comparison stay mandatory.
//
//  Assumes an iPhone-portrait recording of the MoveMark root tabs (dark header on top, light sheet below,
//  floating dock at the bottom), at any scale; regions are in points of a 402 pt-wide screen.
//
//  Per frame it measures:
//  - HEADER_MISMATCH: the dark header band (below the status bar) is not pixel-close to any header seen while
//    the screen was settled. Two titles, a ghosted title, or a half-faded header all land here. (A reselect
//    scroll-to-top also moves the header; those are reported but expected — check the sheet.)
//  - HEADER_WASH: the header band's median luminance is far above the dark header colour (grey wash).
//  - TITLE_ROWS: more rows of bright title text in the header band than any settled header has.
//  - DIM: the content band's dominant luminance is well below the light sheet / white cards (whole-screen dim).
//  - BLANK: the content band has much less ink than any settled frame (near-empty surface).
//  Writes frames.csv, flags.txt, and contact sheets (sheet-NN.png) around every switch.
//

import AVFoundation
import CoreImage
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreText

// MARK: - Args

let argv = CommandLine.arguments
guard argv.count >= 3 else {
    print("usage: ios-nav-frame-scan.swift <video> <out-dir> [--label NAME]")
    exit(2)
}
let videoURL = URL(fileURLWithPath: argv[1])
let outDir = URL(fileURLWithPath: argv[2])
var label = videoURL.deletingPathExtension().lastPathComponent
if let i = argv.firstIndex(of: "--label"), argv.indices.contains(i + 1) { label = argv[i + 1] }
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// MARK: - Regions (points on a 402 pt-wide portrait screen)

let W = 402                       // analysis width (1 px = 1 pt)
let headerBand = 64..<200         // below the status bar, inside every root page's dark header at scroll top
let contentBand = 330..<700        // inside the sheet, above the dock
let darkHeader = 0.09             // #161817
let washLimit = 0.22
let headerMatchLimit = 0.012      // mean |Δluma| over the band
let settleGap = 0.30              // s with no visible change → settled

// MARK: - Frame reading

struct Frame {
    let index: Int
    let time: Double
    let luma: [Float]             // W × H, 0…1
    let height: Int
    let thumb: CGImage
}

let asset = AVURLAsset(url: videoURL)
let sema = DispatchSemaphore(value: 0)
var trackOpt: AVAssetTrack?
Task {
    trackOpt = try? await asset.loadTracks(withMediaType: .video).first
    sema.signal()
}
sema.wait()
guard let track = trackOpt else { print("no video track"); exit(1) }
let reader = try AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(output)
reader.startReading()
let ci = CIContext(options: [.useSoftwareRenderer: false])
let gray = CGColorSpaceCreateDeviceGray()
let rgb = CGColorSpaceCreateDeviceRGB()

func lumaBuffer(_ image: CGImage) -> ([Float], Int) {
    let h = Int((Double(image.height) * Double(W) / Double(image.width)).rounded())
    var bytes = [UInt8](repeating: 0, count: W * h)
    let ctx = CGContext(data: &bytes, width: W, height: h, bitsPerComponent: 8, bytesPerRow: W, space: gray, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    ctx.interpolationQuality = .medium
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: W, height: h))
    return (bytes.map { Float($0) / 255 }, h)
}

func thumbnail(_ image: CGImage, width: Int) -> CGImage {
    let h = Int(Double(image.height) * Double(width) / Double(image.width))
    let ctx = CGContext(data: nil, width: width, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: rgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: h))
    return ctx.makeImage()!
}

var frames: [Frame] = []
while let sample = output.copyNextSampleBuffer() {
    guard let pb = CMSampleBufferGetImageBuffer(sample) else { continue }
    let t = CMSampleBufferGetPresentationTimeStamp(sample).seconds
    let ciImage = CIImage(cvPixelBuffer: pb)
    guard let cg = ci.createCGImage(ciImage, from: ciImage.extent) else { continue }
    let (l, h) = lumaBuffer(cg)
    frames.append(Frame(index: frames.count, time: t, luma: l, height: h, thumb: thumbnail(cg, width: 201)))
}
guard let first = frames.first else { print("no frames"); exit(1) }
let H = first.height
print("\(label): \(frames.count) frames, \(String(format: "%.1f", frames.last!.time - first.time)) s, \(W)×\(H) analysis")

// MARK: - Measures

func rows(_ f: Frame, _ r: Range<Int>) -> ArraySlice<Float> {
    f.luma[(r.lowerBound * W)..<(min(r.upperBound, f.height) * W)]
}

func mad(_ a: ArraySlice<Float>, _ b: ArraySlice<Float>) -> Double {
    var s: Float = 0
    for (x, y) in zip(a, b) { s += abs(x - y) }
    return Double(s) / Double(max(a.count, 1))
}

func median(_ a: ArraySlice<Float>) -> Double {
    var hist = [Int](repeating: 0, count: 256)
    for v in a { hist[min(255, Int(v * 255))] += 1 }
    var acc = 0
    for (i, c) in hist.enumerated() { acc += c; if acc * 2 >= a.count { return Double(i) / 255 } }
    return 1
}

func dominant(_ a: ArraySlice<Float>) -> Double {
    var hist = [Int](repeating: 0, count: 32)
    for v in a { hist[min(31, Int(v * 32))] += 1 }
    let i = hist.indices.max { hist[$0] < hist[$1] }!
    return (Double(i) + 0.5) / 32
}

/// Ink = clearly dark pixels on the light sheet (text, icons, photos).
func ink(_ a: ArraySlice<Float>) -> Double {
    Double(a.reduce(0) { $0 + ($1 < 0.7 ? 1 : 0) }) / Double(max(a.count, 1))
}

/// Separate horizontal runs of bright (title-text) pixels in the header band.
func titleRows(_ f: Frame) -> Int {
    var runs = 0
    var inRun = false
    for y in headerBand where y < f.height {
        var bright = 0
        for x in 16..<(W - 16) where f.luma[y * W + x] > 0.75 { bright += 1 }
        let isText = bright > 6
        if isText && !inRun { runs += 1 }
        inRun = isText
    }
    return runs
}

let fullDiff: [Double] = frames.indices.map { i in
    i == 0 ? 1 : mad(frames[i].luma[...], frames[i - 1].luma[...])
}

// Settled: nothing visibly changes for `settleGap` after this frame.
var settled = [Bool](repeating: false, count: frames.count)
for i in frames.indices {
    var j = i + 1
    var stable = true
    while j < frames.count, frames[j].time - frames[i].time < settleGap {
        if mad(frames[j].luma[...], frames[i].luma[...]) > 0.002 { stable = false; break }
        j += 1
    }
    settled[i] = stable
}

// The app is on screen from the first frame whose header band is the dark header (skips the home screen and
// launch screen at the start of a recording).
let appStart = frames.indices.first { median(rows(frames[$0], headerBand)) < washLimit } ?? 0
for i in 0..<appStart { settled[i] = false }

var references: [ArraySlice<Float>] = []
var maxRefRows = 0
var minRefInk = 1.0
for i in frames.indices where settled[i] {
    let band = rows(frames[i], headerBand)
    if !references.contains(where: { mad($0, band) < headerMatchLimit / 3 }) { references.append(band) }
    maxRefRows = max(maxRefRows, titleRows(frames[i]))
    minRefInk = min(minRefInk, ink(rows(frames[i], contentBand)))
}
print("settled frames: \(settled.filter { $0 }.count), distinct settled headers: \(references.count), title rows ≤ \(maxRefRows), settled ink ≥ \(String(format: "%.3f", minRefInk))")

// MARK: - Per-frame flags

struct Row { var flags: [String]; var headerMAD, headerMedian, contentDominant, contentInk: Double; var titleRows: Int }
var table: [Row] = []
for f in frames {
    if f.index < appStart {
        table.append(Row(flags: [], headerMAD: 0, headerMedian: 0, contentDominant: 0, contentInk: 0, titleRows: 0))
        continue
    }
    let band = rows(f, headerBand)
    let hm = references.map { mad($0, band) }.min() ?? 0
    let med = median(band)
    let content = rows(f, contentBand)
    let dom = dominant(content)
    let k = ink(content)
    let tr = titleRows(f)
    var flags: [String] = []
    if hm > headerMatchLimit { flags.append("HEADER_MISMATCH") }
    if med > washLimit { flags.append("HEADER_WASH") }
    if tr > maxRefRows { flags.append("TITLE_ROWS") }
    if dom < 0.85 { flags.append("DIM") }
    if k < minRefInk * 0.5 { flags.append("BLANK") }
    table.append(Row(flags: flags, headerMAD: hm, headerMedian: med, contentDominant: dom, contentInk: k, titleRows: tr))
}

var csv = "frame,time,settled,full_diff,header_mad,header_median,title_rows,content_dominant,content_ink,flags\n"
for (i, r) in table.enumerated() {
    csv += String(format: "%d,%.4f,%d,%.4f,%.4f,%.3f,%d,%.3f,%.4f,", i, frames[i].time - first.time, settled[i] ? 1 : 0, fullDiff[i], r.headerMAD, r.headerMedian, r.titleRows, r.contentDominant, r.contentInk)
    csv += r.flags.joined(separator: "|") + "\n"
}
try csv.write(to: outDir.appendingPathComponent("frames.csv"), atomically: true, encoding: .utf8)

// MARK: - Events (a settled screen starts changing)

var events: [Int] = []
/// The screen had been still for `settleGap` up to (and including) frame `i`.
func restingThrough(_ i: Int) -> Bool {
    guard i >= appStart else { return false }
    var j = i - 1
    while j >= appStart, frames[i].time - frames[j].time < settleGap {
        if mad(frames[j].luma[...], frames[i].luma[...]) > 0.002 { return false }
        j -= 1
    }
    return j >= appStart || frames[i].time - frames[appStart].time >= settleGap
}

for i in 1..<frames.count where fullDiff[i] > 0.004 && (restingThrough(i - 1) || frames[i].time - frames[i - 1].time >= settleGap) && i - 1 >= appStart {
    if let last = events.last, frames[i].time - frames[last].time < 0.05 { continue }
    events.append(i)
}

let flagged = table.indices.filter { !table[$0].flags.isEmpty }
var report = "\(label)\napp on screen from frame \(appStart) (t=\(String(format: "%.2f", frames[appStart].time - first.time))s)\nframes \(frames.count), events (switches/scrolls) \(events.count), flagged frames \(flagged.count)\n"
var counts: [String: Int] = [:]
for i in flagged { for f in table[i].flags { counts[f, default: 0] += 1 } }
for (k, v) in counts.sorted(by: { $0.key < $1.key }) { report += "  \(k): \(v)\n" }
for i in flagged {
    report += String(format: "  frame %d t=%.3f %@ (headerMAD %.4f median %.3f rows %d dominant %.2f ink %.3f)\n", i, frames[i].time - first.time, table[i].flags.joined(separator: ","), table[i].headerMAD, table[i].headerMedian, table[i].titleRows, table[i].contentDominant, table[i].contentInk)
}
try report.write(to: outDir.appendingPathComponent("flags.txt"), atomically: true, encoding: .utf8)
print(report.split(separator: "\n").prefix(12).joined(separator: "\n"))

// MARK: - Contact sheets: every frame from just before each event until the screen settles (max 24)

func drawText(_ s: String, in ctx: CGContext, at p: CGPoint, color: CGColor, size: CGFloat = 11) {
    let font = CTFontCreateWithName("Menlo" as CFString, size, nil)
    let attr = NSAttributedString(string: s, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color])
    let line = CTLineCreateWithAttributedString(attr)
    ctx.textPosition = p
    CTLineDraw(line, ctx)
}

func writePNG(_ image: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let tw = first.thumb.width, th = first.thumb.height
let cols = 8
for (n, e) in events.enumerated() {
    var idx: [Int] = [max(0, e - 1)]
    var j = e
    // At least 400 ms after the event (small dock motion barely moves the full-frame difference), then until settled.
    while j < frames.count, idx.count < 24 {
        idx.append(j)
        if settled[j] && j > e && frames[j].time - frames[e].time > 0.4 { break }
        j += 1
    }
    let rowsN = (idx.count + cols - 1) / cols
    let cellH = th + 18
    let ctx = CGContext(data: nil, width: cols * tw, height: rowsN * cellH + 22, bitsPerComponent: 8, bytesPerRow: 0, space: rgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(gray: 0.15, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: cols * tw, height: rowsN * cellH + 22))
    let totalH = rowsN * cellH + 22
    drawText("\(label) · event \(n + 1) at t=\(String(format: "%.3f", frames[e].time - first.time))s · red = flagged", in: ctx, at: CGPoint(x: 6, y: totalH - 15), color: CGColor(gray: 1, alpha: 1), size: 12)
    for (k, i) in idx.enumerated() {
        let x = (k % cols) * tw
        let y = totalH - 22 - (k / cols + 1) * cellH
        ctx.draw(frames[i].thumb, in: CGRect(x: x, y: y + 18, width: tw, height: th))
        let bad = !table[i].flags.isEmpty
        if bad {
            ctx.setStrokeColor(CGColor(red: 1, green: 0.1, blue: 0.1, alpha: 1)); ctx.setLineWidth(4)
            ctx.stroke(CGRect(x: x + 2, y: y + 20, width: tw - 4, height: th - 4))
        }
        let tag = String(format: "#%d %+.0fms", i, (frames[i].time - frames[e].time) * 1000) + (bad ? " " + table[i].flags.map { String($0.prefix(6)) }.joined(separator: ",") : "")
        drawText(tag, in: ctx, at: CGPoint(x: x + 3, y: y + 5), color: bad ? CGColor(red: 1, green: 0.4, blue: 0.4, alpha: 1) : CGColor(gray: 0.9, alpha: 1), size: 9)
    }
    writePNG(ctx.makeImage()!, outDir.appendingPathComponent(String(format: "sheet-%02d.png", n + 1)))
}
print("contact sheets: \(events.count) in \(outDir.path)")
