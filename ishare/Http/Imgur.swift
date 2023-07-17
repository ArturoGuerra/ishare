//
//  Imgur.swift
//  ishare
//
//  Created by Adrian Castro on 14.07.23.
//

import SwiftyJSON
import Alamofire
import Foundation
import Defaults
import AppKit

func imgurUpload(_ fileURL: URL, completion: @escaping () -> Void) {
    @Default(.captureFileType) var fileType
    @Default(.imgurClientId) var imgurClientId
    
    let url = "https://api.imgur.com/3/upload"
    
    AF.upload(multipartFormData: { multipartFormData in
        multipartFormData.append(fileURL, withName: "image", fileName: "ishare.\(fileType)", mimeType: "image/\(fileType)")
    }, to: url, method: .post, headers: ["Authorization": "Client-ID " + imgurClientId]).response { response in
        if let data = response.data {
            let json = JSON(data)
            if let link = json["data"]["link"].string {
                print("Image uploaded successfully. Link: \(link)")
                
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                
                pasteboard.setString(link, forType: .string)
                completion()
            } else {
                print("Error parsing response or retrieving image link")
                completion()
            }
        }
    }
}
