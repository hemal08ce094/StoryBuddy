//
//  SpringyDuoGetStarted.swift
//  PurposefulSwiftUIAnimations

//  ANIMATION AND MEANING: Delight and Whimsy
//  Yes, you can animate things just for fun and whimsy. The Duolingo getstarted animation makes it fun and delightful to get started to use the app. The playful animation here can help Duolingo win users over other language learning apps.

//  Making the resting state bouncy makes the animation more fun and playful

import SwiftUI

struct SpringyDuoGetStarted: View {
    @State private var isBlinking = false
    @State private var isTilting = false
    @State private var isRaising = false
    @State private var isWaving = false
    @State private var isShouting = false
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                ZStack {
                    // Body
                    Image("body")
                    
                    HStack(spacing: 82) {
                        Image("rightHand")
                            .rotationEffect(.degrees(isWaving ? 0 : 90), anchor: .topTrailing)
                            .onTapGesture {
                                HapticEngine.play(.tap)
                            }
                        
                        Image("leftHand")
                            .rotationEffect(.degrees(isWaving ? 0 : -10), anchor: .topLeading)
                            .animation(.interpolatingSpring(stiffness: 170, damping: 5), value: isWaving)
                            .onTapGesture {
                                HapticEngine.play(.tap)
                            }
                    }
                    
                    // Face
                    VStack {
                        Image("face")
                            .onTapGesture {
                                HapticEngine.play(.selection)
                            }
                        Image("mouth")
                            .onTapGesture {
                                HapticEngine.play(.selection)
                            }
                    }
                    
                    // Eyes, Nose and thoung
                    VStack(spacing: -12) {
                        
                        // Eyes
                        HStack(spacing: 32) {
                            ZStack { // Left eye
                                Image("eyelid")
                                Image("pipul")
                            }
                            .onTapGesture {
                                HapticEngine.play(.selection)
                            }
                            
                            ZStack { // Right eye
                                Image("eyelid")
                                Image("pipul")
                            }
                            .onTapGesture {
                                HapticEngine.play(.selection)
                            }
                        }
                        .scaleEffect(y: isBlinking ? 1 : 0)
                        
                        // Nose, thoung
                        VStack(spacing: -8) {
                            Image("nose")
                                .zIndex(1)
                                .onTapGesture {
                                    HapticEngine.play(.selection)
                                }
                            Image("thoung")
                                .scaleEffect(x: isShouting ? 1.4 : 1)
                                .offset(y: isShouting ? -3: 4 )
                                .onTapGesture {
                                    HapticEngine.play(.selection)
                                }
                        }
                        .padding(.bottom)
                    }
                }
                .rotationEffect(.degrees(isTilting ? 0 : 15))
                .animation(.interpolatingSpring(stiffness: 800, damping: 5).delay(2), value: isTilting)
                
                // Left and right hands
                HStack(spacing: 32) {
                    Image("legRight")
                        .rotationEffect(.degrees(isRaising ? 0 : -30), anchor: .bottomLeading)
                        .offset(x: isRaising ? 5 : 0)
                        .animation(.interpolatingSpring(stiffness: 170, damping: 8).delay(2), value: isRaising)
                        .onTapGesture {
                            HapticEngine.play(.tap)
                        }
                    Image("legLeft")
                        .onTapGesture {
                            HapticEngine.play(.tap)
                        }
                }
            } // All views
            .onAppear{
                HapticEngine.play(.play)
                
                withAnimation(.easeOut(duration: 0.2).delay(0.25).repeatCount(2)) {
                    isBlinking.toggle()
                    HapticEngine.play(.selection)
                }
                
                withAnimation(.easeInOut(duration: 0.2).delay(0.5*4).repeatCount(1, autoreverses: true)) {
                    isTilting.toggle()
                    HapticEngine.play(.scrub)
                }
                
                withAnimation(.easeOut(duration: 0.2).repeatCount(11, autoreverses: true)) {
                    isWaving.toggle()
                    HapticEngine.play(.selection)
                }
                
                withAnimation(.easeInOut(duration: 1).delay(0.5*3.4).repeatCount(1, autoreverses: true)) {
                    isRaising.toggle()
                    HapticEngine.play(.scrub)
                }
                
                withAnimation(.easeInOut(duration: 1).delay(0.5*3.4).repeatCount(1, autoreverses: true)) {
                    isShouting.toggle()
                    HapticEngine.play(.selection)
                }
            }
            
            // Floor
            Image("floor")
                .onTapGesture {
                    HapticEngine.play(.tap)
                }
        } // All views
    }
}

struct SpringyDuoGetStarted_Previews: PreviewProvider {
    static var previews: some View {
        SpringyDuoGetStarted()
            .preferredColorScheme(.dark)
    }
}
