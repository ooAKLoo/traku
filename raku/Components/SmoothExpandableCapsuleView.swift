import SwiftUI

struct SmoothExpandableCapsuleView: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                // 背景 - 实现平滑的颜色过渡
                Capsule()
                    .fill(Color.blue)
                    .frame(
                        width: isExpanded ? 300 : 80,
                        height: 80
                    )
                
                // 前景内容
                if isExpanded {
                    // 展开状态的内容
                    Text("展开的胶囊")
                        .foregroundColor(.white)
                        .font(.headline)
                        .transition(.opacity)
                } else {
                    // 收缩状态的内容
                    Image(systemName: "circle.fill")
                        .foregroundColor(.white)
                        .font(.title)
                        .transition(.opacity)
                }
            }
            .onTapGesture {
                withAnimation(.interpolatingSpring(
                    mass: 1.0,
                    stiffness: 100.0,
                    damping: 15.0
                )) {
                    isExpanded.toggle()
                }
            }
            
            Spacer()
            
            Text(isExpanded ? "点击收缩" : "点击展开")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // 重置按钮
            Button("重置") {
                withAnimation {
                    isExpanded = false
                }
            }
            .padding()
        }
    }
}

// 更高级的版本，带有更多自定义选项
struct AdvancedExpandableCapsuleView: View {
    @State private var isExpanded = false
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                // 主体形状 - 动态变化
                RoundedRectangle(cornerRadius: isExpanded ? 40 : 40)
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(
                        width: isExpanded ? 300 : 80,
                        height: 80
                    )
                    .scaleEffect(scale)
                
                // 内容
                if isExpanded {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundColor(.white)
                        Text("展开状态")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onTapGesture {
                // 添加点击缩放效果
                withAnimation(.easeInOut(duration: 0.1)) {
                    scale = 0.95
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.interpolatingSpring(
                        mass: 1.0,
                        stiffness: 200.0,
                        damping: 20.0
                    )) {
                        scale = 1.0
                        isExpanded.toggle()
                    }
                }
            }
            
            Spacer()
            
            // 控制按钮
            HStack {
                Button("收缩") {
                    guard isExpanded else { return }
                    withAnimation(.interpolatingSpring(
                        mass: 1.0,
                        stiffness: 150.0,
                        damping: 20.0
                    )) {
                        isExpanded = false
                    }
                }
                .disabled(!isExpanded)
                .padding()
                
                Button("展开") {
                    guard !isExpanded else { return }
                    withAnimation(.interpolatingSpring(
                        mass: 1.0,
                        stiffness: 150.0,
                        damping: 20.0
                    )) {
                        isExpanded = true
                    }
                }
                .disabled(isExpanded)
                .padding()
            }
        }
    }
}

struct ContentView223: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("选择动画效果")
                    .font(.largeTitle)
                    .padding()
                
                NavigationLink("基础平滑效果") {
                    SmoothExpandableCapsuleView()
                }
                .padding()
                
                NavigationLink("高级效果") {
                    AdvancedExpandableCapsuleView()
                }
                .padding()
            }
        }
    }
}

struct SmoothExpandableCapsuleView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView223()
    }
}
