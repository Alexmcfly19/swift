
import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var app: AppState
    
    // MARK: - Profile fields (pre-filled to match the provided screenshot)
    @State private var fullName: String = "Philipa Rout"
    @State private var username: String = "Philirout"
    @State private var phone: String = "+44 234 11 2455"
    @State private var email: String = "p.rout@gmail.com"
    @State private var website: String = "rout.philapaa"
    @State private var languages: Set<String> = ["English", "Latin"]
    @State private var isPrivate: Bool = true
    @State private var locationPerm: Bool = false
    
    // avatar
    @State private var avatar: UIImage? = UIImage(named: "avatar-philipa")
    @State private var showPhotoPicker = false
    
    // error/status
    @State private var error: String?
    @State private var status: String?
    
    var body: some View {
        ZStack {
            Image("bg-earth-2")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(.black.opacity(0.25))
            
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    Text("ReChord")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(radius: 6)
                        .padding(.top, 8)
                    
                    // Profile Card
                    card {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                if let avatar {
                                    Image(uiImage: avatar)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Circle()
                                        .fill(.gray.opacity(0.2))
                                        .overlay(
                                            Text(initials(from: fullName))
                                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                        )
                                }
                            }
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
                            .onTapGesture { showPhotoPicker = true }
                            .accessibilityLabel("Change profile photo")
                            
                            VStack(spacing: 12) {
                                iconField(system: "person.fill", placeholder: "Full name", text: $fullName)
                                iconField(system: "at", placeholder: "@username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }
                    }
                    
                    // About Me (voice clip)
                    card(title: "About me") {
                        HStack(spacing: 14) {
                            circleButton(system: "play.fill")
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        // simple waveform placeholder
                                        WaveformView()
                                            .padding(.horizontal, 12)
                                    )
                                    .frame(height: 46)
                                HStack {
                                    Spacer()
                                    circleButton(system: "dot.waveform")
                                }
                                .padding(.trailing, 8)
                            }
                        }
                    }
                    
                    // Contact options
                    card(title: "Contact Options") {
                        iconField(system: "phone.fill", placeholder: "Phone", text: $phone)
                            .keyboardType(.phonePad)
                        iconField(system: "envelope.fill", placeholder: "Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                        iconField(system: "link", placeholder: "Website / username", text: $website)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    // Language preference
                    card(title: "Language Preference") {
                        FlowLayout(alignment: .leading, spacing: 10) {
                            ForEach(["English","Latin","Spanish","French"], id: \.self) { lang in
                                Tag(language: lang, isSelected: languages.contains(lang)) {
                                    if languages.contains(lang) {
                                        languages.remove(lang)
                                    } else {
                                        languages.insert(lang)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            toggleRow(title: "Private Account", isOn: $isPrivate)
                            toggleRow(title: "Location Permission", isOn: $locationPerm)
                        }
                        .padding(.top, 4)
                    }
                    
                    // Save / sync button
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        Text("Save Changes")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(.white.opacity(0.15))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.35)))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
                    
                    if let status {
                        Text(status)
                            .font(.footnote).foregroundStyle(.white.opacity(0.8))
                    }
                    if let error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                    
                    Spacer(minLength: 30)
                    
                    // Lightweight bottom bar
                    HStack(spacing: 38) {
                        Image(systemName: "paperplane")
                        Image(systemName: "globe")
                        ZStack {
                            Circle().fill(.white.opacity(0.2)).frame(width: 54, height: 54)
                            Circle().stroke(.white.opacity(0.5))
                            Image(systemName: "record.circle")
                                .font(.title2)
                        }
                        Image(systemName: "at")
                        Image(systemName: "person.circle")
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 16)
            }
        }
        .task { await loadProfile() }
        .photosPicker(isPresented: $showPhotoPicker, selection: .constant(nil))
    }
    
    // MARK: - Reusable pieces
    
    func card<Content: View>(title: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 2)
            }
            VStack(spacing: 12) { content() }
                .padding(14)
                .background(.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.horizontal, 2)
    }
    
    func iconField(system: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: system)
                .frame(width: 28, alignment: .center)
                .foregroundStyle(.white.opacity(0.9))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
                .placeholder(when: text.wrappedValue.isEmpty) {
                    Text(placeholder).foregroundStyle(.white.opacity(0.6))
                }
        }
    }
    
    func circleButton(system: String) -> some View {
        Button { } label: {
            Image(systemName: system)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.15))
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.35)))
        }
        .buttonStyle(.plain)
    }
    
    func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.95))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(12)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    func initials(from name: String) -> String {
        let comps = name.split(separator: " ")
        let letters = comps.prefix(2).compactMap { $0.first }
        return letters.map { String($0) }.joined()
    }
    
    // MARK: - Networking
    @MainActor
    func saveProfile() async {
        guard let token = app.token, let id = app.currentUserId else {
            self.status = "Saved locally. (No token)"
            return
        }
        var fields: [String: Any] = [
            "name": fullName,
            "username": username,
            "email": email,
            "phone": phone,
            "website": website,
            "languages": Array(languages),
            "is_private": isPrivate ? 1 : 0,
            "location_permission": locationPerm ? 1 : 0
        ]
        do {
            try await APIClient.shared.updateClient(id: id, fields: fields, token: token)
            if let img = avatar {
                try await APIClient.shared.uploadAvatar(image: img, clientId: id, token: token)
            }
            self.status = "Saved"
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Small helpers

fileprivate struct Tag: View {
    let language: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected { Image(systemName: "xmark") }
                Text(language)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? .white.opacity(0.18) : .white.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(isSelected ? 0.5 : 0.25)))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct WaveformView: View {
    var body: some View {
        GeometryReader { geo in
            let bars = 28
            let w = geo.size.width / CGFloat(bars)
            HStack(spacing: 2) {
                ForEach(0..<bars, id: \.self) { i in
                    let h = CGFloat((sin(Double(i)) + 1.5) / 2.5) * (geo.size.height * 0.7)
                    RoundedRectangle(cornerRadius: 2)
                        .frame(width: w * 0.6, height: max(8, h))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
        }
    }
}

// Flow layout for chips
fileprivate struct FlowLayout<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: () -> Content
    
    init(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        _Flow(content: content, spacing: spacing)
    }
    
    private struct _Flow<Content: View>: View {
        let content: () -> Content
        let spacing: CGFloat
        
        var body: some View {
            VStack(alignment: .leading, spacing: spacing) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// Placeholder modifier
fileprivate extension View {
    @ViewBuilder
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            if shouldShow { content() }
            self
        }
    }

    }

extension ProfileView {
    @MainActor
    func loadProfile() async {
        guard let token = app.token, let id = app.currentUserId else { return }
        do {
            let p = try await APIClient.shared.showClientById(id: id, token: token)
            if let v = p.name { self.fullName = v }
            if let v = p.username { self.username = v }
            if let v = p.email { self.email = v }
            if let v = p.phone { self.phone = v }
            if let v = p.website { self.website = v }
            if let v = p.isPrivate { self.isPrivate = v }
            if let v = p.locationPermission { self.locationPerm = v }
            if let v = p.languages { self.languages = Set(v) }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
}
