
import SwiftUI
import PhotosUI

// MARK: - AppState placeholder you can integrate with your auth/session
final class AppState: ObservableObject {
    @Published var token: String? = nil
    @Published var currentUserId: Int? = nil
}

// MARK: - Models
struct ClientProfile: Codable {
    var id: Int?
    var name: String?
    var username: String?
    var email: String?
    var phone: String?
    var website: String?
    var isPrivate: Bool?
    var locationPermission: Bool?
    var languages: [String]?
    var avatarURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name = "full_name"
        case username
        case email
        case phone
        case website = "blog_link"
        case isPrivate = "is_private"
        case locationPermission = "location_permission"
        case languages
        case avatarURL = "avatar_link"
    }
}

// MARK: - API Client using ShowById / UpdateClient / Avatar Upload
actor APIClient {
    static let shared = APIClient()
    private let base = URL(string: "https://be.rechord.life/public/api")!
    
    struct APIError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    
    // ShowById
    func showClientById(id: Int, token: String) async throws -> ClientProfile {
        var req = URLRequest(url: base.appendingPathComponent("clients/show/\(id)"))
        req.httpMethod = "POST"
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError(message: "ShowById failed")
        }
        // Backend usually wraps data; try to decode common shapes
        if let profile = try? JSONDecoder().decode(ClientProfile.self, from: data) {
            return profile
        }
        // Fallback: attempt nested "data"
        struct Wrap: Codable { let data: ClientProfile }
        if let wrap = try? JSONDecoder().decode(Wrap.self, from: data) {
            return wrap.data
        }
        throw APIError(message: "Unexpected ShowById payload")
    }
    
    // UpdateClient (multipart/form-data)
    func updateClient(id: Int, fields: [String: Any], token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("clients/\(id)"))
        req.httpMethod = "POST"
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        func appendField(_ key: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Map fields to API names
        if let v = fields["name"] as? String { appendField("full_name", v) }
        if let v = fields["username"] as? String { appendField("username", v) }
        if let v = fields["phone"] as? String { appendField("phone", v) }
        if let v = fields["email"] as? String { appendField("email", v) }
        if let v = fields["website"] as? String { appendField("blog_link", v) }
        if let v = fields["bio_link"] as? String { appendField("bio_link", v) }
        if let v = fields["is_private"] as? Int { appendField("is_private", String(v)) }
        if let v = fields["location_permission"] as? Int { appendField("location_permission", String(v)) }
        if let v = fields["languages"] as? [String] { appendField("languages", v.joined(separator: ",")) }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError(message: "UpdateClient failed")
        }
    }
    
    // Avatar Upload (multipart/form-data)
    func uploadAvatar(image: UIImage, clientId: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("avatar"))
        req.httpMethod = "POST"
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        func appendField(_ key: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // client_id
        appendField("client_id", String(clientId))
        // avatar file
        guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
            throw APIError(message: "Could not encode avatar")
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        req.httpBody = body
        
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError(message: "Avatar upload failed")
        }
    }
}

// MARK: - Profile UI (matches the provided design)
struct ProfileView: View {
    @EnvironmentObject var app: AppState
    
    // Pre-filled defaults to mirror screenshot
    @State private var fullName: String = "Philipa Rout"
    @State private var username: String = "Philirout"
    @State private var phone: String = "+44 234 11 2455"
    @State private var email: String = "p.rout@gmail.com"
    @State private var website: String = "rout.philippaa"
    @State private var languages: Set<String> = ["English", "Latin"]
    @State private var isPrivate: Bool = true
    @State private var locationPerm: Bool = false
    
    // Avatar
    @State private var avatar: UIImage? = nil
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem? = nil
    
    // Status
    @State private var error: String?
    @State private var status: String?
    
    var body: some View {
        ZStack {
            // Background
            Image("bg-earth-2")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(.black.opacity(0.25))
            
            ScrollView {
                VStack(spacing: 20) {
                    Text("ReChord")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(radius: 6)
                        .padding(.top, 8)
                    
                    card {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                if let avatar {
                                    Image(uiImage: avatar).resizable().scaledToFill()
                                } else {
                                    Circle().fill(.gray.opacity(0.2))
                                        .overlay(Text(initials(from: fullName))
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white))
                                }
                            }
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
                            .onTapGesture { showPicker = true }
                            .accessibilityLabel("Change profile photo")
                            
                            VStack(spacing: 12) {
                                iconField(system: "person.fill", placeholder: "Full name", text: $fullName)
                                iconField(system: "at", placeholder: "@username", text: $username)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                            }
                        }
                    }
                    
                    // About me (waveform bar with play & record buttons)
                    card(title: "About me") {
                        HStack(spacing: 14) {
                            circleButton(system: "play.fill")
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .frame(height: 46)
                                    .overlay(WaveformView().padding(.horizontal, 12))
                                HStack {
                                    Spacer()
                                    circleButton(system: "dot.waveform")
                                }.padding(.trailing, 8)
                            }
                        }
                    }
                    
                    // Contact Options
                    card(title: "Contact Options") {
                        iconField(system: "phone.fill", placeholder: "Phone", text: $phone).keyboardType(.phonePad)
                        iconField(system: "envelope.fill", placeholder: "Email", text: $email)
                            .textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
                        iconField(system: "link", placeholder: "Website / username", text: $website)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    
                    // Languages + toggles
                    card(title: "Language Preference") {
                        FlowLayout(alignment: .leading, spacing: 10) {
                            ForEach(["English","Latin","Spanish","French"], id: \.self) { lang in
                                Tag(language: lang, isSelected: languages.contains(lang)) {
                                    if languages.contains(lang) { languages.remove(lang) } else { languages.insert(lang) }
                                }
                            }
                        }.padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            toggleRow(title: "Private Account", isOn: $isPrivate)
                            toggleRow(title: "Location Permission", isOn: $locationPerm)
                        }.padding(.top, 4)
                    }
                    
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
                    
                    if let status { Text(status).font(.footnote).foregroundStyle(.white.opacity(0.8)) }
                    if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                    
                    Spacer(minLength: 30)
                    
                    // Bottom bar
                    HStack(spacing: 38) {
                        Image(systemName: "paperplane")
                        Image(systemName: "globe")
                        ZStack {
                            Circle().fill(.white.opacity(0.2)).frame(width: 54, height: 54)
                            Circle().stroke(.white.opacity(0.5))
                            Image(systemName: "record.circle").font(.title2)
                        }
                        Image(systemName: "at")
                        Image(systemName: "person.circle")
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 12)
                }.padding(.horizontal, 16)
            }
        }
        .task { await loadProfile() }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem)
        .onChange(of: pickerItem) { _, newItem in
            Task { await loadSelectedPhoto(newItem) }
        }
    }
    
    // MARK: - Helpers
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
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.25), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.padding(.horizontal, 2)
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
        Button {} label: {
            Image(systemName: system)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.15))
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.35)))
        }.buttonStyle(.plain)
    }
    
    func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).foregroundStyle(.white.opacity(0.95))
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(.green)
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
    
    @MainActor
    func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let img = UIImage(data: data) {
            self.avatar = img
        }
    }
    
    // MARK: - Networking hooks
    @MainActor
    func saveProfile() async {
        guard let token = app.token, let id = app.currentUserId else {
            self.status = "Saved locally. (No token)"
            return
        }
        var payload: [String: Any] = [
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
            try await APIClient.shared.updateClient(id: id, fields: payload, token: token)
            if let img = avatar {
                try await APIClient.shared.uploadAvatar(image: img, clientId: id, token: token)
            }
            self.status = "Saved"
        } catch {
            self.error = error.localizedDescription
        }
    }
    
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

// MARK: - Reusable subviews
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
        }.buttonStyle(.plain)
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

fileprivate extension View {
    @ViewBuilder
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            if shouldShow { content() }
            self
        }
    }
}
