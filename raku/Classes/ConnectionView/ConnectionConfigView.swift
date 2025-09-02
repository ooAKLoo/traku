//
//  ConnectionConfigView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/29.
//

import SwiftUI

struct ConnectionConfigView: View {
    @ObservedObject var audioManager: AudioManagerAdapter
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @State private var isConnecting = false
    @State private var manualIP = "192.168.5.49"
    @State private var manualPort = "81"
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                LinearGradient(
                    colors: isDarkMode ?
                        [Color.black, Color(white: 0.05)] :
                        [Color(white: 0.95), Color(white: 0.98)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // 标题区域
                    VStack(spacing: 15) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: isDarkMode ?
                                            [Color.blue.opacity(0.2), Color.purple.opacity(0.2)] :
                                            [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(isDarkMode ? .white : .black)
                        }
                        
                        Text("ESP32 设备连接")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        if audioManager.isConnected {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text(audioManager.connectionStatus)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.green)
                            }
                        } else {
                            Text("输入ESP32设备的IP地址和端口")
                                .font(.system(size: 16))
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                        }
                    }
                    .padding(.top, 20)
                    
                    // 连接配置
                    ManualConfigView(
                        manualIP: $manualIP,
                        manualPort: $manualPort,
                        isDarkMode: isDarkMode
                    ) {
                        connectToESP32()
                    }
                    
                    // 连接状态信息
                    if isConnecting {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: isDarkMode ? .white : .black))
                                .scaleEffect(0.8)
                            Text("正在连接...")
                                .font(.system(size: 14))
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                        )
                    }
                    
                    // 说明信息
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(isDarkMode ? .blue.opacity(0.8) : .blue)
                            Text("连接说明")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• 确保手机与ESP32设备在同一WiFi网络")
                            Text("• 设备会自动被发现并显示在列表中")
                            Text("• 点击设备即可连接")
                            Text("• 如果未发现设备，可手动输入IP地址")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("设备管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(isDarkMode ? .white : .black)
                }
                
                if audioManager.isConnected {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("断开") {
                            audioManager.disconnectFromDevice()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    func connectToESP32() {
        guard !manualIP.isEmpty else { return }
        
        isConnecting = true
        print("正在连接ESP32设备: \(manualIP):\(manualPort)")
        
        // 直接连接到指定IP和端口
        audioManager.connectToESP32(ip: manualIP, port: Int(manualPort) ?? 81)
        
        // 使用更短的检查间隔来监听连接状态
        checkConnectionStatus()
    }
    
    private func checkConnectionStatus() {
        // 每秒检查一次连接状态，最多检查15秒
        var checkCount = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            checkCount += 1
            
            print("检查连接状态 [\(checkCount)/15]: isConnected=\(audioManager.isConnected), status=\(audioManager.connectionStatus)")
            
            if audioManager.isConnected {
                print("连接成功！关闭连接配置窗口")
                isConnecting = false
                timer.invalidate()
                dismiss()
            } else if checkCount >= 15 {
                print("连接超时，停止检查")
                isConnecting = false
                timer.invalidate()
            }
        }
    }
}


// MARK: - 手动配置视图
struct ManualConfigView: View {
    @Binding var manualIP: String
    @Binding var manualPort: String
    let isDarkMode: Bool
    let onConnect: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 8) {
                Text("IP地址")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                
                TextField("192.168.1.100", text: $manualIP)
                    .textFieldStyle(ModernTextFieldStyle(isDarkMode: isDarkMode))
                    .keyboardType(.numbersAndPunctuation)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("端口")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                
                TextField("81", text: $manualPort)
                    .textFieldStyle(ModernTextFieldStyle(isDarkMode: isDarkMode))
                    .keyboardType(.numberPad)
            }
            
            Button(action: onConnect) {
                Text("连接")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isDarkMode ? Color.white : Color.black)
                    )
                    .foregroundColor(isDarkMode ? .black : .white)
            }
            .disabled(manualIP.isEmpty)
            .opacity(manualIP.isEmpty ? 0.5 : 1.0)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

// MARK: - 现代文本框样式
struct ModernTextFieldStyle: TextFieldStyle {
    let isDarkMode: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundColor(isDarkMode ? .white : .black)
    }
}

