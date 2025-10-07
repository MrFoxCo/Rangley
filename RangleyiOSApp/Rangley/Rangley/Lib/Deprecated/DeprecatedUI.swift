//
//  DeprecatedUI.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/7/25.
//

// Max Capacity
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Max Capacity")
//                    .font(.system(size: 14, weight: .semibold))
//                    .foregroundColor(AppPalette.Text.secondary)
//
//                HStack {
//                    Text("\(vm.maxCapacity) people")
//                        .font(.system(size: 16))
//                        .foregroundColor(AppPalette.Text.primary)
//
//                    Spacer()
//
//                    HStack(spacing: 16) {
//                        Button {
//                            if vm.maxCapacity > 2 {
//                                vm.maxCapacity -= 1
//                            }
//                        } label: {
//                            Image(systemName: "minus.circle.fill")
//                                .font(.system(size: 28))
//                                .foregroundColor(vm.maxCapacity > 2 ? AppPalette.Brand.neonPink : AppPalette.Text.tertiary)
//                        }
//                        .disabled(vm.maxCapacity <= 2)
//
//                        Button {
//                            if vm.maxCapacity < 50 {
//                                vm.maxCapacity += 1
//                            }
//                        } label: {
//                            Image(systemName: "plus.circle.fill")
//                                .font(.system(size: 28))
//                                .foregroundColor(vm.maxCapacity < 50 ? AppPalette.Brand.neonPink : AppPalette.Text.tertiary)
//                        }
//                        .disabled(vm.maxCapacity >= 50)
//                    }
//                }
//                .padding(16)
//                .background(
//                    RoundedRectangle(cornerRadius: 12)
//                        .fill(AppPalette.Surface.fieldFill)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 12)
//                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
//                        )
//                )
//            }
//DetailRow(label: "Max Capacity", value: "\(vm.maxCapacity) people")

//// Max Capacity
//VStack(alignment: .leading, spacing: 8) {
//    Text("Max Capacity")
//        .font(.system(size: 14, weight: .semibold))
//        .foregroundColor(AppPalette.Text.secondary)
//    
//    HStack {
//        Text("\(vm.maxCapacity) people")
//            .font(.system(size: 16))
//            .foregroundColor(AppPalette.Text.primary)
//        
//        Spacer()
//        
//        HStack(spacing: 16) {
//            Button {
//                if vm.maxCapacity > 2 {
//                    vm.maxCapacity -= 1
//                }
//            } label: {
//                Image(systemName: "minus.circle.fill")
//                    .font(.system(size: 28))
//                    .foregroundColor(vm.maxCapacity > 2 ? AppPalette.Brand.neonPink : AppPalette.Text.tertiary)
//            }
//            .disabled(vm.maxCapacity <= 2)
//            
//            Button {
//                if vm.maxCapacity < 50 {
//                    vm.maxCapacity += 1
//                }
//            } label: {
//                Image(systemName: "plus.circle.fill")
//                    .font(.system(size: 28))
//                    .foregroundColor(vm.maxCapacity < 50 ? AppPalette.Brand.neonPink : AppPalette.Text.tertiary)
//            }
//            .disabled(vm.maxCapacity >= 50)
//        }
//    }
//    .padding(16)
//    .background(
//        RoundedRectangle(cornerRadius: 12)
//            .fill(AppPalette.Surface.fieldFill)
//            .overlay(
//                RoundedRectangle(cornerRadius: 12)
//                    .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
//            )
//    )
//}
//
//DetailRow(label: "Max Capacity", value: "\(vm.maxCapacity) people")
