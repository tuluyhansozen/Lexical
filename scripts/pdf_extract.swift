#!/usr/bin/swift

import Foundation
import PDFKit

// PDF Text Extractor
// Usage: swift pdf_extract.swift <input_pdf_path> <output_txt_path>

guard CommandLine.arguments.count == 3 else {
    print("Usage: swift pdf_extract.swift <input_pdf> <output_txt>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

let url = URL(fileURLWithPath: inputPath)

guard let document = PDFDocument(url: url) else {
    print("Error: Could not load PDF at \(inputPath)")
    exit(1)
}

// Check if document is encrypted
if document.isEncrypted {
    print("Warning: Document is encrypted. Extraction might fail.")
}

var fullText = ""
let pageCount = document.pageCount

print("Extracting text from \(pageCount) pages...")

for i in 0..<pageCount {
    if let page = document.page(at: i) {
        if let pageText = page.string {
            fullText += pageText + "\n"
        }
    }
}

do {
    try fullText.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
    print("✅ Extracted text to \(outputPath)")
    print("   Length: \(fullText.count) characters")
} catch {
    print("Error writing output: \(error)")
    exit(1)
}
