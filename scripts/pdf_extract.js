// JXA PDF Extractor
ObjC.import('PDFKit');
ObjC.import('Foundation');

function run(argv) {
    if (argv.length < 1) {
        console.log("Usage: osascript -l JavaScript pdf_extract.js <input_pdf>");
        return;
    }

    var inputPath = argv[0];
    var url = $.NSURL.fileURLWithPath(inputPath);
    var doc = $.PDFDocument.alloc.initWithURL(url);

    if (doc.isNil()) {
        return;
    }

    var pageCount = doc.pageCount;
    var fullText = "";

    for (var i = 0; i < pageCount; i++) {
        var page = doc.pageAtIndex(i);
        var text = page.string.js;
        if (text) {
            fullText += text + "\n";
        }
    }

    // Return text to stdout
    return fullText;
}
