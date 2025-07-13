//
//  JustBreathe.swift
//  Just Breath
//
//  ANIMATION AND MEANING: Guiding Users. In guided meditation, animations are normally used to guide users to complete tasks.
//

import SwiftUI

struct JustBreathe: View {
    
    @Binding var isAnimating: Bool
    
    @State private var grow = false // Scale the middle from 0.5 to 1
    @State private var rotateFarRight = false
    @State private var rotateFarLeft = false
    @State private var rotateMiddleLeft = false
    @State private var rotateMiddleRight = false
    @State private var showShadow = false
    @State private var showRightStroke = false
    @State private var showLeftStroke = false
    @State private var changeColor = false
    
    var body: some View {
        VStack {
            Spacer()
            
            // Pull content from DetailsViwl.swift
            //JustBreatheDetailsView()
            
            Spacer()
            
            ZStack {
                
                Image("flower") // Middle
                    .scaleEffect(grow ? 1 : 0.5, anchor: .bottom)
                    .animation(.easeInOut(duration: 2).delay(2).repeatForever(autoreverses: true), value: grow)
                    .onAppear {
                        HapticEngine.play(.selection)
                    }
                
                Image("flower")  // Middle left
                    .rotationEffect(.degrees( rotateMiddleLeft ? -25 : -5), anchor: .bottom)
                    .animation(.easeInOut(duration: 2).delay(2).repeatForever(autoreverses: true), value: rotateMiddleLeft)
                    .onAppear {
                        if isAnimating {
                            rotateMiddleLeft.toggle()
                        }
                        HapticEngine.play(.selection)
                    }
                
                Image("flower")  // Middle right
                    .rotationEffect(.degrees( rotateMiddleRight ? 25 : 5), anchor: .bottom)
                    .animation(.easeInOut(duration: 2).delay(2).repeatForever(autoreverses: true), value: rotateMiddleRight)
                    .onAppear {
                        HapticEngine.play(.selection)
                    }
                
                Image("flower")  // Left
                    .rotationEffect(.degrees( rotateFarLeft ? -50 : -10), anchor: .bottom)
                    .animation(.easeInOut(duration: 2).delay(2).repeatForever(autoreverses: true), value: rotateFarLeft)
                    .onAppear {
                        HapticEngine.play(.selection)
                    }
                
                Image("flower")  // Right
                    .rotationEffect(.degrees( rotateFarRight ? 50 : 10), anchor: .bottom)
                    .animation(.easeInOut(duration: 2).delay(2).repeatForever(autoreverses: true), value: rotateFarRight)
                    .onAppear {
                        HapticEngine.play(.selection)
                    }
                
                Circle()  // Quarter dotted circle left
                    .trim(from: showLeftStroke ? 0 : 1/4, to: 1/4)
                    .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [1, 14]))
                    .frame(width: 215, height: 215, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                    .foregroundColor(Color(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)))
                    .rotationEffect(.degrees(-180), anchor: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                    .offset(x: 0, y: -25)
                    .animation(.easeInOut(duration: 2).delay(2).repeatForever(autoreverses: true), value: showLeftStroke)
                
                Circle()  // Quarter dotted circle right
                    .trim(from: 0, to: showRightStroke ? 1/4 : 0)
                    .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [1, 14]))
                    .frame(width: 215, height: 215, alignment: .center)
                    .foregroundColor(Color(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)))
                    .rotationEffect(.degrees(-90), anchor: .center)
                    .offset(x: 0, y: -25)
                    .animation(.easeInOut(duration: 2).delay(2).repeatForever(autoreverses: true), value: showRightStroke)
                
            } // Container for flower
            .shadow(radius: showShadow ? 20 : 0) // Switching from flat to elevation
            .hueRotation(Angle(degrees: changeColor ? -235 : 45)) // Animating Chroma
            .animation(.easeInOut(duration: 2).delay(2).repeatForever(autoreverses: true), value: changeColor)
            
            Spacer()
            
//            Button("End"){
//                print("End button tapped!")
//            }
//            .buttonStyle(.borderedProminent)
//            
//            Spacer()
            
        } // Container for all views
        .onAppear {
            if isAnimating {
                startAnimations()
            } else {
                resetAnimations()
            }
        }
        .onChange(of: isAnimating) { newValue in
            if newValue {
                startAnimations()
            } else {
                resetAnimations()
            }
        }
    }
    
    private func startAnimations() {
        changeColor = false
        showShadow = false
        showRightStroke = false
        showLeftStroke = false
        rotateFarRight = false
        rotateFarLeft = false
        rotateMiddleRight = false
        rotateMiddleLeft = false
        grow = false
        
        HapticEngine.play(.play)
        
        // Start all toggles to true to start animations with repeatForever
        changeColor.toggle()
        showShadow.toggle()
        showRightStroke.toggle()
        showLeftStroke.toggle()
        rotateFarRight.toggle()
        rotateFarLeft.toggle()
        rotateMiddleRight.toggle()
        rotateMiddleLeft.toggle()
        grow.toggle()
    }
    
    private func resetAnimations() {
        changeColor = false
        showShadow = false
        showRightStroke = false
        showLeftStroke = false
        rotateFarRight = false
        rotateFarLeft = false
        rotateMiddleRight = false
        rotateMiddleLeft = false
        grow = false
        
        HapticEngine.play(.pause)
    }
}

struct JustBreathe_Previews: PreviewProvider {
    static var previews: some View {
        JustBreathe(isAnimating: .constant(true))
            .preferredColorScheme(.dark)
    }
}
