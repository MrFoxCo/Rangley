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


struct ThemedDateOnlyPicker: UIViewRepresentable {
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
