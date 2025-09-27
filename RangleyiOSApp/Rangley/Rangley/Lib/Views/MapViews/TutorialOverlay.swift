//
//  TutorialOverlay.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/27/25.
//

//
//  TutorialOverlay.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/27/25.
//

import SwiftUI

// MARK: - Tutorial Configuration
struct TutorialConfig {
    static let steps: [TutorialStepData] = [
        TutorialStepData(
            title: "Welcome to Rangley!",
            description: "Rangley helps you create and join in-person hangouts — we call these 'meets.' Whether it's tennis, coffee, or anything else, let's show you around. Tap anywhere to continue."
        ),
        TutorialStepData(
            title: "Create a Meet",
            description: "Tap on the map to drop a meet wherever you want to hang out."
        ),
        TutorialStepData(
            title: "Meet Bubbles",
            description: "Each colorful pig bubble is a meet. Tap one to see meet details!"
        ),
        TutorialStepData(
            title: "Quick Create",
            description: "Use the (+) button for a faster way to spin up a meet."
        ),
        TutorialStepData(
            title: "Find Friends",
            description: "Hit the (⌕) search to look up friends or explore meets."
        ),
        TutorialStepData(
            title: "Your Meets",
            description: "Check the ‘My Meets’ button (three-person icon) for invites and all your active meets."
        ),
        TutorialStepData(
            title: "Settings",
            description: "Tap the menu (☰) in the top right for your account and app settings."
        ),
        TutorialStepData(
            title: "All Set!",
            description: "You’re ready to host, join, and meet people around you. Let’s go!"
        )
    ]
}


// MARK: - Data Models
struct TutorialStepData {
    let title: String
    let description: String
}

// MARK: - Tutorial Store
@MainActor
class TutorialStore: ObservableObject {
    func checkShouldShowTutorial() -> Bool {
        return !UserDefaults.standard.bool(forKey: "hasSeenTutorial")
    }
    
    func resetTutorial() {
        UserDefaults.standard.removeObject(forKey: "hasSeenTutorial")
    }
}

// MARK: - Simple Tutorial Overlay
struct SimpleTutorialOverlay: View {
    @ObservedObject var uiState: UIStateStore
    
    private var currentStep: TutorialStepData {
        guard uiState.tutorialStep < TutorialConfig.steps.count else {
            return TutorialConfig.steps.last!
        }
        return TutorialConfig.steps[uiState.tutorialStep]
    }
    
    var body: some View {
        if uiState.showTutorial {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        nextStep()
                    }
                
                // Tutorial card
                VStack(spacing: 24) {
                    // Step indicator
                    HStack(spacing: 8) {
                        ForEach(0..<TutorialConfig.steps.count, id: \.self) { index in
                            Capsule()
                                .fill(index == uiState.tutorialStep ? AppPalette.Brand.neonPink : Color.white.opacity(0.3))
                                .frame(width: index == uiState.tutorialStep ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: uiState.tutorialStep)
                        }
                    }
                    .padding(.top, 8)
                    
                    // Content
                    VStack(spacing: 16) {
                        Text(currentStep.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(currentStep.description)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                    }
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        Button("Skip") {
                            uiState.completeTutorial()
                        }
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Button(uiState.tutorialStep == TutorialConfig.steps.count - 1 ? "Get Started" : "Next") {
                            nextStep()
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppPalette.Brand.neonPink)
                        .cornerRadius(25)
                    }
                    .padding(.top, 8)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppPalette.Brand.japPurple)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(AppPalette.Brand.neonPink.opacity(0.4), lineWidth: 2)
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                .padding(.horizontal, 40)
                .scaleEffect(0.95)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: uiState.tutorialStep)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .zIndex(1000)
        }
    }
    
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            uiState.nextTutorialStep()
        }
    }
}
