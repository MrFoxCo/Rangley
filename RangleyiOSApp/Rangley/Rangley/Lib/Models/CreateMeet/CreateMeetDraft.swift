//
//  CreateMeetDraft.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 8/11/25.
//
import Foundation

public struct CreateMeetDraft: Equatable
{
    public var name         : String = ""
    public var notes        : String = ""
    public var categoryName : String = ""
    public var dttmStart    : Date   = Date().addingTimeInterval(60*30)
    public var dttmEnd      : Date   = Date().addingTimeInterval(60*90)
    public var capacity     : Int    = 4
    public var placeName    : String? = nil

    public var epochRange: EpochRange {
        EpochRange(dttmStart, dttmEnd)
    }
}

// What you send to API/DB:
struct CreateMeetDTO: Encodable {
    let name            : String
    let categoryName    : String
    let dttmStartEpoch  : Int64
    let dttmEndEpoch    : Int64
    let capacity        : Int
}

func makeDTO(from draft: CreateMeetDraft) -> CreateMeetDTO
{
    let r = draft.epochRange
    return .init(
        name            : draft.name,
        categoryName    : draft.categoryName,
        dttmStartEpoch  : r.startEpoch,
        dttmEndEpoch    : r.endEpoch,
        capacity        : draft.capacity
    )
}
