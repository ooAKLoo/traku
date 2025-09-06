import SwiftUI

struct DatabaseDebugView: View {
    @State private var recordCount: Int = 0
    @State private var showingExportAlert = false
    @State private var exportedFileName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 数据库统计信息
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("数据库状态")
                            .font(.headline)
                        
                        HStack {
                            Text("总记录数:")
                            Spacer()
                            Text("\(recordCount)")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("数据库位置:")
                            Spacer()
                            Text("Documents/RakuDatabase.sqlite")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // 操作按钮
                VStack(spacing: 15) {
                    Button(action: refreshStats) {
                        Label("刷新统计", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: exportDebugInfo) {
                        Label("导出调试信息", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: openFilesApp) {
                        Label("在文件App中查看", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                // 使用说明
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("查看数据库文件的方法")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("连接iPhone到电脑", systemImage: "1.circle.fill")
                            Label("打开Finder（Mac）或iTunes（Windows）", systemImage: "2.circle.fill")
                            Label("选择你的设备 > 文件共享 > Raku", systemImage: "3.circle.fill")
                            Label("可以看到并导出数据库文件", systemImage: "4.circle.fill")
                        }
                        .font(.caption)
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("数据库调试")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                refreshStats()
            }
            .alert("导出成功", isPresented: $showingExportAlert) {
                Button("确定") { }
            } message: {
                Text("调试信息已导出到:\n\(exportedFileName)\n\n可通过文件共享功能在电脑上查看")
            }
        }
    }
    
    private func refreshStats() {
        recordCount = DatabaseManager.shared.getRecordingCount()
    }
    
    private func exportDebugInfo() {
        let fileName = DatabaseManager.shared.exportDatabaseDebugInfo()
        exportedFileName = fileName
        showingExportAlert = true
    }
    
    private func openFilesApp() {
        // 获取Documents目录URL
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            if UIApplication.shared.canOpenURL(documentsURL) {
                UIApplication.shared.open(documentsURL)
            }
        }
    }
}

struct DatabaseDebugView_Previews: PreviewProvider {
    static var previews: some View {
        DatabaseDebugView()
    }
}