//
//  ThemedDatePicker.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/27/25.
//

import SwiftUI

struct ThemedDatePicker: UIViewRepresentable
{
    @Binding var selection: Date
    var minimumDate: Date? = nil
    var maximumDate: Date? = nil
    
    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .wheels
        picker.setValue(UIColor.white, forKey: "textColor")
        picker.tintColor = UIColor(AppPalette.Brand.neonPink)
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }
    
    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.date = selection
        uiView.minimumDate = minimumDate
        uiView.maximumDate = maximumDate
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ThemedDatePicker
        
        init(_ parent: ThemedDatePicker) {
            self.parent = parent
        }
        
        @objc func changed(_ sender: UIDatePicker) {
            parent.selection = sender.date
        }
    }
}


struct ThemedDateOnlyPicker: UIViewRepresentable
{
    @Binding var selection: Date
    var minimumDate: Date? = nil
    var maximumDate: Date? = nil
    
    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.setValue(UIColor.white, forKey: "textColor")
        picker.tintColor = UIColor(AppPalette.Brand.neonPink)
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }
    
    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.date = selection
        uiView.minimumDate = minimumDate
        uiView.maximumDate = maximumDate
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ThemedDateOnlyPicker
        
        init(_ parent: ThemedDateOnlyPicker) {
            self.parent = parent
        }
        
        @objc func changed(_ sender: UIDatePicker) {
            parent.selection = sender.date
        }
    }
}

struct ThemedDOBOnlyPicker: UIViewRepresentable
{
    @Binding var selection: Date
    var minimumDate: Date? = nil
    var maximumDate: Date? = nil
    
    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.setValue(UIColor.white, forKey: "textColor")
        picker.tintColor = UIColor(AppPalette.Brand.neonPink)
        
        // Set the date constraints first
        picker.minimumDate = minimumDate
        picker.maximumDate = maximumDate
        
        // Then set the date to a valid value
        if let maxDate = maximumDate {
            picker.date = min(selection, maxDate)
        } else {
            picker.date = selection
        }
        
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }
    
    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.minimumDate = minimumDate
        uiView.maximumDate = maximumDate
        
        // Set date only if it's different and within valid range
        let clampedDate: Date
        if let minDate = minimumDate, let maxDate = maximumDate {
            clampedDate = min(max(selection, minDate), maxDate)
        } else if let maxDate = maximumDate {
            clampedDate = min(selection, maxDate)
        } else if let minDate = minimumDate {
            clampedDate = max(selection, minDate)
        } else {
            clampedDate = selection
        }
        
        if uiView.date != clampedDate {
            uiView.date = clampedDate
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ThemedDOBOnlyPicker
        
        init(_ parent: ThemedDOBOnlyPicker) {
            self.parent = parent
        }
        
        @objc func changed(_ sender: UIDatePicker) {
            parent.selection = sender.date
        }
    }
}
