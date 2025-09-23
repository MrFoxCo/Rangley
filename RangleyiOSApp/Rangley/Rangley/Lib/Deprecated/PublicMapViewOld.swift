////
//onUserSelected: { user in
//                        print("Selected user: \(user.display_name)")
//                        // Handle user selection - maybe show user profile or invite to meet
//                    }
//                )
//                Spacer()
//            }
//            .padding(.bottom, 8)
//        }
//        .task {
//            await authState.updateToken()
//        }
//    }
//}
//
//
//// MARK: - Loading Overlay
//struct LoadingOverlay: View
//{
//    var body: some View
//    {
//        Color.black.opacity(0.3)
//            .ignoresSafeArea()
//        
//        VStack {
//            ProgressView()
//                .scaleEffect(1.5)
//                .progressViewStyle(CircularProgressViewStyle(tint: .white))
//            Text("Loading meets...")
//                .foregroundColor(.white)
//                .padding(.top, 8)
//        }
//    }
//}
//
//
//private func tapHitsAnnotation(_ proxy: MapProxy, _ pt: CGPoint, meets: [ViewMeetsModel]) -> Bool
//{
//    // ~50–60pt radius ≈ your 80pt bubble + padding
//    let r: CGFloat = 50
//    for m in meets {
//        let coord = CLLocationCoordinate2D(latitude: m.latitude, longitude: m.longitude)
//        if let p = proxy.convert(coord, to: .local) {
//            let dx = p.x - pt.x
//            let dy = p.y - pt.y
//            if (dx*dx + dy*dy) <= r*r { return true }
//        }
//    }
//    return false
//}
//
