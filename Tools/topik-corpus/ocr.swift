// OCR a PDF with PDFKit + Vision (Korean). Usage: swift ocr.swift in.pdf out.txt
import Foundation
import PDFKit
import Vision
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let doc = PDFDocument(url: URL(fileURLWithPath: args[1])) else {
    FileHandle.standardError.write("usage: ocr in.pdf out.txt\n".data(using: .utf8)!); exit(1)
}
var out = ""
for i in 0..<doc.pageCount {
    guard let page = doc.page(at: i) else { continue }
    let box = page.bounds(for: .mediaBox)
    let scale: CGFloat = 3
    let w = Int(box.width * scale), h = Int(box.height * scale)
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { continue }
    ctx.setFillColor(NSColor.white.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: ctx)
    guard let img = ctx.makeImage() else { continue }
    let req = VNRecognizeTextRequest()
    req.recognitionLanguages = ["ko-KR", "en-US"]
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = true
    try? VNImageRequestHandler(cgImage: img).perform([req])
    let lines = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    out += "=== page \(i + 1)\n" + lines.joined(separator: "\n") + "\n"
}
try out.write(toFile: args[2], atomically: true, encoding: .utf8)
print("\(args[1]): \(doc.pageCount) pages, \(out.count) chars")
