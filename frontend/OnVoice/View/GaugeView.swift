//
//  GaugeView.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/23/25.
//

import SwiftUI

enum GaugeColorLevel: String {
    case top
    case bottom
}

struct GaugeView: View {
    
    var gaugeHeight: Int = 444
    
    @Binding var noiseMeter: NoiseMeter
    @Binding var currentSituation: Situation?
    
    var dBHighStandard: Int {
        self.currentSituation?.decibels.1 ?? 50
    }

    var dBLowStandard: Int {
        self.currentSituation?.decibels.0 ?? 70
    }
    
    private func getColor(decibels: Float, level: GaugeColorLevel) -> Color {
        let gaugeValue = gaugeHeight * Int(decibels) / 120
        
        let topStandard = gaugeHeight * dBHighStandard / 120
        let bottomStandard = gaugeHeight * dBLowStandard / 120
        
        switch level {
        case .top:
            if gaugeValue > topStandard {
                return Color.suDBlg1
            } else if gaugeValue > bottomStandard {
                return Color.suDBm1
            } else {
                return Color.suDBs1
            }
        case .bottom:
            if gaugeValue > topStandard {
                return Color.suDBlg2
            } else if gaugeValue > bottomStandard {
                return Color.suDBm2
            } else {
                return Color.suDBs2
            }
        }
    }
    
    var body: some View {
        VStack {
            ZStack(alignment: .bottom) {
                ZStack(alignment: .bottom){
                    Color.suGray8
                        .clipShape(RoundedCorner(radius: 0,
                                                 corners: .allCorners))
                        .frame(width: 213, height: 444)
                    
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            LinearGradient(
                                gradient: Gradient(colors: [getColor(decibels: noiseMeter.decibels,
                                                                     level: .top),
                                                            getColor(decibels: noiseMeter.decibels,
                                                                     level: .bottom)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )                                  
                        }
                    }
                    .clipShape(RoundedCorner(radius: 0,
                                             corners: .allCorners))
                    .frame(width: 213,
                           height: CGFloat(gaugeHeight * Int(noiseMeter.decibels) / 120))
                    .background(
                        Color.white
                            .clipShape(RoundedCorner(radius: 0,
                                                     corners: .allCorners))
                            .shadow(color: .white.opacity(0.25),
                                    radius: 8, x: 0, y: 0)
                    )
                    .animation(.easeInOut(duration: 0.5), value: noiseMeter.decibels)
                    
                }
                Rectangle()
                    .stroke(lineWidth: 1)
                    .frame(height: CGFloat(444 * (dBHighStandard - dBLowStandard) / 120))
                    .padding(.horizontal, -1)
                    .padding(.bottom, CGFloat(444 * dBLowStandard) / 120)
            }
            .frame(width: 213, height: 444)
            .background(Color.black)
            .clipShape(RoundedCorner(radius: 32,
                                     corners: .allCorners))
        }
    }
    
}

#Preview {
    GaugeView(noiseMeter: .constant(NoiseMeter()),
              currentSituation: .constant(Situation.loudTalking))
}
