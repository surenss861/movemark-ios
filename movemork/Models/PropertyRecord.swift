//
//  PropertyRecord.swift
//  movemork
//
//  MoveMark — Property vault model.
//

import Foundation

struct PropertyRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var addressLine1: String
    var addressLine2: String
    var city: String
    var provinceState: String
    var postalCode: String
    var landlordName: String
    var landlordEmail: String
    var landlordPhone: String
    var moveInDate: Date
    var leaseStartDate: Date?
    var leaseEndDate: Date
    var depositAmount: String
    var rentAmount: String
    var country: String
    var rooms: [RoomRecord]
    var vaultDocuments: [String]

    init(
        id: UUID = UUID(),
        title: String = "",
        addressLine1: String,
        addressLine2: String = "",
        city: String = "",
        provinceState: String = "",
        postalCode: String = "",
        landlordName: String = "",
        landlordEmail: String = "",
        landlordPhone: String = "",
        moveInDate: Date,
        leaseStartDate: Date? = nil,
        leaseEndDate: Date,
        depositAmount: String = "",
        rentAmount: String = "",
        country: String = "CA",
        rooms: [RoomRecord] = [],
        vaultDocuments: [String] = []
    ) {
        self.id = id
        self.title = title
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.city = city
        self.provinceState = provinceState
        self.postalCode = postalCode
        self.landlordName = landlordName
        self.landlordEmail = landlordEmail
        self.landlordPhone = landlordPhone
        self.moveInDate = moveInDate
        self.leaseStartDate = leaseStartDate
        self.leaseEndDate = leaseEndDate
        self.depositAmount = depositAmount
        self.rentAmount = rentAmount
        self.country = country
        self.rooms = rooms
        self.vaultDocuments = vaultDocuments
    }
}
