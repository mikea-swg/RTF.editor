//
//  File.swift
//  RTFEditorPackage
//
//  Created by Josip Bernat on 23.06.2025..
//

import Foundation

public struct FileMetadata: Codable {
    
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(createdAt: Date, updatedAt: Date) {
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func withNewUpdatedAt(_ newUpdatedAt: Date = Date()) -> FileMetadata {
        FileMetadata(createdAt: createdAt, updatedAt: newUpdatedAt)
    }
}
