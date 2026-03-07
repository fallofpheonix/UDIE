import SwiftUI

struct CommandPalette: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    
    let commands = [
        CommandItem(title: "Fly to AIIMS Cluster", icon: "map.fill", category: "Navigation"),
        CommandItem(title: "Evaluate Route: Okhla -> CP", icon: "arrow.triangle.turn.up.right.diamond.fill", category: "Routing"),
        CommandItem(title: "Run Simulation: Flooding", icon: "bolt.fill", category: "Simulation"),
        CommandItem(title: "View Risk Trends", icon: "chart.line.uptrend.xyaxis", category: "Analytics"),
        CommandItem(title: "System Diagnostics", icon: "cpu", category: "System")
    ]
    
    var filteredCommands: [CommandItem] {
        if searchText.isEmpty { return commands }
        return commands.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 0) {
                // Search Header
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ColorTokens.textSecondary)
                    TextField("Type a command or search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(Typography.body)
                    
                    Text("ESC")
                        .font(.caption2.bold())
                        .padding(4)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding()
                .background(ColorTokens.adaptiveSurface)
                
                Divider()
                
                // Results List
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredCommands) { command in
                            Button(action: {
                                // Execute command
                                isPresented = false
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: command.icon)
                                        .foregroundStyle(ColorTokens.accent)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading) {
                                        Text(command.title)
                                            .font(Typography.bodySmall.bold())
                                        Text(command.category)
                                            .font(.system(size: 10))
                                            .foregroundStyle(ColorTokens.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "return")
                                        .font(.caption2)
                                        .foregroundStyle(ColorTokens.textSecondary)
                                }
                                .padding()
                                .background(ColorTokens.adaptiveSurface)
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

struct CommandItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let category: String
}
