//
//  main.swift
//  dedupe
//
//  Created by David Garcia on 8/30/22.
//

import Cocoa
import AVFoundation
import _Concurrency

let fileManager = FileManager.default
let home = fileManager.homeDirectoryForCurrentUser.absoluteURL
//let path = URL(fileURLWithPath: "/Volumes/Storage/Traktor Library old", isDirectory: true)
let path = URL(fileURLWithPath: "New_Library/old_list", isDirectory: true, relativeTo: home)
let contents: [URL] = try! fileManager.contentsOfDirectory(atPath: path.path).sorted().map{URL(fileURLWithPath: $0,relativeTo: path)}
let destDir = URL(fileURLWithPath: "New_Library/list", isDirectory: true, relativeTo: fileManager.homeDirectoryForCurrentUser)
var count = 0;
let file = URL(fileURLWithPath: "dupes.txt", isDirectory: false, relativeTo: destDir)
func moveFile(dest: URL, song: URL){
    print("Moving \(song.lastPathComponent) to \(dest.path)")
//    try? fileManager.copyItem(at: song, to: URL(fileURLWithPath: song.lastPathComponent, relativeTo: destDir))
    count += 1
}
Task{
    
    // Title : File Path
    // We're going to move all the duplicates to another folder and just keep the best non-duplicates
    var masters = [ String: URL ]()
    for songPath in contents {
        let song = AVAsset(url: songPath)
        // Move all these songs first
        if songPath.pathExtension == "aif" ||
            songPath.pathExtension == "aiff" ||
            songPath.pathExtension == "wav" {
            moveFile(dest: destDir, song: songPath)
        } else {
            do{
                // If song extension isn't one of those above, then we need to compare mp3s and m4as
                let metadata = try await song.load(AVAsyncProperty<AVAsset, Any>.metadata)
                if let title = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierTitle).first?.stringValue {
                    if masters[title] == nil{
                        masters[title] = songPath
                    } else {
                        let old_path = masters[title]
                        // If old song is mp3, we want m4a instead
                        if old_path!.pathExtension == "mp3" && songPath.pathExtension == "m4a"{
                            masters[title] = songPath
                        } else if old_path!.pathExtension == songPath.pathExtension {
                            let old_size = try old_path?.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).fileSize ?? 0
                            let new_size = try songPath.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).fileSize ?? 0
                            let newSongName = songPath.deletingPathExtension().lastPathComponent
                            let oldSongName = old_path!.deletingPathExtension().lastPathComponent
                            
                            //If current song is contained in old song's file name, it's probably in the format of
                            // song x.mp3 and we just want the one the says song.mp3
                            // If they have the same extension but one file size is bigger, let's assume that means it's a higher bitrate
                            if newSongName.contains(oldSongName) ||
                                oldSongName.compare(newSongName) == .orderedDescending ||
                                new_size > old_size {
                                masters[title] = songPath
                                do {
                                    // write dupes
                                    try songPath.lastPathComponent.write(toFile: file.path, atomically: true, encoding: .utf8)
                                    try old_path?.lastPathComponent.write(toFile: file.path, atomically: true, encoding: .utf8)
                                }catch {
                                    print(error)
                                }
                                print(songPath.lastPathComponent)
                                print(old_path!.lastPathComponent)
                            }
                        }
                    }
                }
            }catch {
                continue
            }
        }
    }
    masters.forEach{moveFile(dest: destDir, song: $0.value)}
    print("\(masters.count) unique songs out of \(contents.count) total songs")
    
}
sleep(10000)

