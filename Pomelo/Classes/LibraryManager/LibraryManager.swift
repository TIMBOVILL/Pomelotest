//
//  LibraryManager.swift
//  Pomelo
//
//  Created by Jarrod Norwell on 1/18/24.
//

import Sudachi

import Foundation
import UIKit

struct MissingFile : Hashable, Identifiable {
    enum FileImportance : String, CustomStringConvertible {
        case optional = "Optional", required = "Required"
        
        var description: String {
            rawValue
        }
    }
    
    var id = UUID()
    
    let coreName: Core.Name
    let directory: URL
    var fileImportance: FileImportance
    let fileName: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(coreName)
        hasher.combine(directory)
        hasher.combine(fileImportance)
        hasher.combine(fileName)
    }
}

enum Core2 : String, Codable, Hashable {
    enum Console : String, Codable, Hashable {
        case nSwitch = "Nintendo Switch"
        
        var shortened: String {
            switch self {
            case .nSwitch: "3DS"
            }
        }
    }
    
    case Sudachi = "Sudachi"
    
    var console: Console {
        switch self {
        case .Sudachi: .nSwitch
        }
    }
    
    var isNintendo: Bool {
        self == .Sudachi
    }
    

    
    static let cores: [Core2] = [.Sudachi]
}


struct Core : Comparable, Hashable {
    enum Name : String, Hashable {
        case Sudachi = ""
    }
    
    enum Console : String, Hashable {
        case nSwitch = "Nintendo Switch"
        
        func buttonColors() -> [VirtualControllerButton.ButtonType : UIColor] {
            switch self {
            default:
                [
                    :
                ]
            }
        }
    }
    
    let console: Console
    let name: Name
    var games: [AnyHashable]
    var missingFiles: [MissingFile]
    let root: URL
    
    static func < (lhs: Core, rhs: Core) -> Bool {
        lhs.name.rawValue < rhs.name.rawValue
    }
}

class DirectoriesManager {
    static let shared = DirectoriesManager()
    
    func directories() -> [String : [String : MissingFile.FileImportance]] {
        [
                "amiibo" : [:],
                "cache" : [:],
                "config" : [:],
                "crash_dumps" : [:],
                "dump" : [:],
                "keys" : [
                    "prod.keys" : .required,
                    "title.keys" : .required
                ],
                "load" : [:],
                "log" : [:],
                "nand" : [:],
                "play_time" : [:],
                "roms" : [:],
                "screenshots" : [:],
                "sdmc" : [:],
                "shader" : [:],
                "tas" : [:],
                "icons" : [:]
    
        ]
    }
    
    func createMissingDirectoriesInDocumentsDirectory() throws {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try directories().forEach { directory, _ in
            let coreDirectory = documentsDirectory.appendingPathComponent(directory, conformingTo: .folder)
            if !FileManager.default.fileExists(atPath: coreDirectory.path) {
                try FileManager.default.createDirectory(at: coreDirectory, withIntermediateDirectories: false)
            }
        }
    }
    
    func scanDirectoriesForRequiredFiles(for core: inout Core) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        directories().forEach { directory in
            directory.value.forEach { subdirectory, fileNames in
                let coreSubdirectory = documentsDirectory.appendingPathComponent(directory.key, conformingTo: .folder)
                    .appendingPathComponent(subdirectory, conformingTo: .folder)
                
                // Ensure fileNames is treated as a dictionary of [String: MissingFile.FileImportance]
                if let fileNamesDict = fileNames as? [String: MissingFile.FileImportance] {
                    fileNamesDict.forEach { (fileName, fileImportance) in
                        if !FileManager.default.fileExists(atPath: coreSubdirectory.appendingPathComponent(fileName, conformingTo: .fileURL).path) {
                            core.missingFiles.append(.init(coreName: core.name, directory: coreSubdirectory, fileImportance: fileImportance, fileName: fileName))
                        }
                    }
                }
            }
        }
    }
}

enum LibraryManagerError : Error {
    case invalidEnumerator, invalidURL
}

class LibraryManager {
    static let shared = LibraryManager()
    
    func library() throws -> [Core] {
        func romsDirectoryCrawler(for coreName: Core.Name) throws -> [URL] {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            guard let enumerator = FileManager.default.enumerator(at: documentsDirectory.appendingPathComponent(coreName.rawValue, conformingTo: .folder)
                .appendingPathComponent("roms", conformingTo: .folder), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
                throw LibraryManagerError.invalidEnumerator
            }
            
            var urls: [URL] = []
            try enumerator.forEach { element in
                switch element {
                case let url as URL:
                    let attributes = try url.resourceValues(forKeys: [.isRegularFileKey])
                    if let isRegularFile = attributes.isRegularFile, isRegularFile {
                        switch coreName {
#if canImport(Sudachi)
                        case .Sudachi:
                            if ["nca", "nro", "nso", "nsp", "xci"].contains(url.pathExtension.lowercased()) {
                                urls.append(url)
                            }
#endif
                        default:
                            break
                        }
                    }
                default:
                    break
                }
            }
            
            return urls
        }
        
        func games(from urls: [URL], for core: inout Core) {
            switch core.name {
#if canImport(Sudachi)
            case .Sudachi:
                core.games = urls.reduce(into: [SudachiGame]()) { partialResult, element in
                    let information = Sudachi.shared.information(for: element)
                
                    let game = SudachiGame(core: core, developer: information.developer, fileURL: element,
                                           imageData: information.iconData,
                                           title: information.title)
                    partialResult.append(game)
                }
#endif
            default:
                break
            }
        }
        
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
#if canImport(Cytrus)
        var cytrusCore = Core(console: .n3ds, name: .cytrus, games: [], missingFiles: [], root: directory.appendingPathComponent(Core.Name.cytrus.rawValue, conformingTo: .folder))
        games(from: try romsDirectoryCrawler(for: .cytrus), for: &cytrusCore)
        DirectoriesManager.shared.scanDirectoriesForRequiredFiles(for: &cytrusCore)
#endif
        
#if canImport(Sudachi)
        var SudachiCore = Core(console: .nSwitch, name: .Sudachi, games: [], missingFiles: [], root: directory.appendingPathComponent(Core.Name.Sudachi.rawValue, conformingTo: .folder))
        games(from: try romsDirectoryCrawler(for: .Sudachi), for: &SudachiCore)
        DirectoriesManager.shared.scanDirectoriesForRequiredFiles(for: &SudachiCore)
#endif
        
#if canImport(Cytrus)
        return [cytrusCore, grapeCore, kiwiCore]
#elseif canImport(Sudachi)
        return [SudachiCore]
#endif
    }
}
