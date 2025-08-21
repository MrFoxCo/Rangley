//
//  ErrorEnums.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 8/18/25.
//

//MARK: Exception/ Error handling
public enum DatabaseError: Error {
    case insertionFailed(String)
    case deletionFailed(String)
    case modifyFailed(String)
    case viewFailed(String)
    case parameterMismatch(String)
}
