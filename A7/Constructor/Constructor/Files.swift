import Foundation

//An example of a file you can incrementally print to...

//func open (_ outputFile: inout FileHandle?, _ fileName: String) {
//    let outputPath = "users/kyleaitken/documents/" + fileName
//    FileManager.default.createFile(atPath: outputPath, contents: nil, attributes: nil)
//    outputFile = FileHandle (forWritingAtPath: outputPath)
//}


func open(_ outputFile: inout FileHandle?, _ fileName: String) {
    let outputPath = "\(NSHomeDirectory())/Documents/\(fileName)"
    let fileCreated = FileManager.default.createFile(atPath: outputPath, contents: nil, attributes: nil)
    if !fileCreated {
        print("Failed to create file at path: \(outputPath)")
    }
    outputFile = FileHandle(forWritingAtPath: outputPath)
    if outputFile == nil {
        print("Failed to open file at path: \(outputPath)")
    }
}


func close (_ outputFile: inout FileHandle?) {
    do {
        try outputFile?.close()
    } catch {
        print ("Error detected when attempting to close the file")
    }
}

func write (_ outputFile: inout FileHandle?, _ string: String) {
    do {
        try outputFile?.write (contentsOf: Data (string.utf8))
    } catch {
        print("Error detected when attempting to write to the file")
    }
}

public func incrementalFilesExample () {
    var output: FileHandle?
    open (&output, "output.txt")
    write (&output, "This is")
    write (&output, "the start of")
    write (&output, "\nsomething new")
    close (&output)
}
