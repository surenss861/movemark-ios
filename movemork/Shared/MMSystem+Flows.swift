//
//  MMSystem+Flows.swift
//  movemork
//
//  @file Flow building blocks on top of MMSystem: the dark evidence sheet (a sheet that edits a room's
//        evidence opens from the dark room screen, so it stays dark), its field / chip / notice / photo strip,
//        a quiet status label and a dated step row for light screens. Lime stays on the one primary action.
//  @domain design-system
//  @see [[MMSystem.swift]]
//

import SwiftUI

// MARK: - Dark evidence surface

/// A sheet on the evidence surface: #111312, white text, white/12% strokes, native dark bar (Cancel / title).
struct MMEvidenceSheetScaffold<Content: View, Footer: View>: View {
    var title: String
    /// False hides the pinned footer bar entirely (e.g. Add photos before anything is chosen).
    var showsFooter: Bool
    var content: () -> Content
    var footer: () -> Footer

    init(title: String, showsFooter: Bool = true, @ViewBuilder content: @escaping () -> Content,
         @ViewBuilder footer: @escaping () -> Footer) {
        self.title = title
        self.showsFooter = showsFooter
        self.content = content
        self.footer = footer
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content() }
                .padding(.horizontal, MMMetrics.inset)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsFooter {
                footer()
                    .padding(.horizontal, MMMetrics.inset)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .background(MMInk.evidence.ignoresSafeArea(edges: .bottom))
                    .overlay(alignment: .top) { Rectangle().fill(MMInk.evidenceStroke).frame(height: 0.5) }
            }
        }
        .background(MMInk.evidence.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MMInk.evidence, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }
}

/// Caption over an evidence control (sentence case, quiet).
struct MMEvidenceCaption: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).mmFont(13, .medium).foregroundStyle(MMInk.heroSecondary)
            Spacer(minLength: 8)
            if let detail { Text(detail).mmFont(12.5).foregroundStyle(MMInk.heroSecondary) }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A dark text field: caption above, raised fill, hairline stroke, white text.
struct MMEvidenceField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var axis: Axis = .horizontal
    var accessibilityID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MMEvidenceCaption(title: title)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Color.white.opacity(0.38)), axis: axis)
                .lineLimit(axis == .vertical ? 2...6 : 1...1)
                .mmFont(16)
                .foregroundStyle(.white)
                .tint(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .frame(minHeight: 50)
                .background(MMInk.evidenceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(MMInk.evidenceStroke, lineWidth: 1))
                .accessibilityLabel(title)
                .accessibilityIdentifier(accessibilityID ?? title)
        }
    }
}

/// A selectable chip on the evidence surface: white when selected, outlined otherwise. Never green.
struct MMEvidenceChip: View {
    let title: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .mmFont(14, isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? MMInk.evidence : Color.white.opacity(0.88))
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(isSelected ? Color.white : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : MMInk.evidenceStroke, lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(MMLightPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Issue tags as chips in a wrapping row.
struct MMEvidenceTagPicker: View {
    let tags: [String]
    @Binding var selected: Set<String>
    var onToggle: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MMEvidenceCaption(title: "Issue tags", detail: selected.isEmpty ? "Optional" : "\(selected.count) selected")
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    MMEvidenceChip(title: tag, isSelected: selected.contains(tag)) {
                        onToggle?()
                        if selected.contains(tag) { selected.remove(tag) } else { selected.insert(tag) }
                    }
                }
            }
        }
    }
}

/// Condition as a native segmented control on the evidence surface.
struct MMEvidenceConditionPicker: View {
    @Binding var condition: RoomRecord.ConditionRating

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MMEvidenceCaption(title: "Condition")
            Picker("Condition", selection: $condition) {
                ForEach(RoomRecord.ConditionRating.allCases, id: \.self) { rating in
                    Text(rating.rawValue).tag(rating)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// A calm notice on the evidence surface (error / warning / info / success), with an optional action.
struct MMEvidenceNotice: View {
    let message: String
    var tone: MMNotice.Tone = .error
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    static let dangerOnDark = Color(red: 1.0, green: 0.478, blue: 0.431)
    static let warningOnDark = Color(red: 0.949, green: 0.737, blue: 0.341)

    private var mark: (String, Color) {
        switch tone {
        case .error: ("exclamationmark.circle.fill", Self.dangerOnDark)
        case .warning: ("exclamationmark.triangle.fill", Self.warningOnDark)
        case .info: ("info.circle.fill", MMInk.heroSecondary)
        case .success: ("checkmark.circle.fill", MMInk.limeMark)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: mark.0).foregroundStyle(mark.1).font(.system(size: 15))
            Text(message).mmFont(14).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action).mmFont(14, .semibold).foregroundStyle(.white)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MMInk.evidenceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(MMInk.evidenceStroke, lineWidth: 0.75))
        .accessibilityElement(children: .combine)
    }
}

/// Photos on the evidence surface: real thumbnails, or quiet tiles when only the count is known.
struct MMEvidencePhotoStrip: View {
    var images: [UIImage] = []
    var placeholderCount: Int = 0

    private var tileCount: Int { images.isEmpty ? placeholderCount : images.count }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<min(tileCount, 4), id: \.self) { index in
                Group {
                    if index < images.count {
                        Image(uiImage: images[index]).resizable().scaledToFill()
                    } else {
                        MMInk.evidenceRaised.overlay {
                            Image(systemName: "photo").font(.system(size: 16)).foregroundStyle(MMInk.heroSecondary)
                        }
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(MMInk.evidenceStroke, lineWidth: 0.75))
            }
            if tileCount > 4 {
                Text("+\(tileCount - 4)")
                    .mmFont(14, .medium)
                    .foregroundStyle(MMInk.heroSecondary)
                    .frame(width: 64, height: 64)
                    .background(MMInk.evidenceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tileCount == 1 ? "1 photo" : "\(tileCount) photos")
    }
}

// MARK: - Light screens

/// A quiet status: a small mark and a word. Open is amber, closed is ink; never a filled pill.
struct MMStatusLabel: View {
    enum Tone { case open, done, neutral }
    let text: String
    var tone: Tone = .neutral

    var body: some View {
        HStack(spacing: 6) {
            switch tone {
            case .open: Circle().fill(MMInk.warning).frame(width: 7, height: 7)
            case .done: Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(MMInk.text)
            case .neutral: Circle().fill(MMInk.secondary.opacity(0.6)).frame(width: 7, height: 7)
            }
            Text(text).mmFont(13, .medium).foregroundStyle(tone == .neutral ? MMInk.secondary : MMInk.text)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A dated step in a record (discovered → reported → response → follow-up): a rail mark, title, value.
struct MMRecordStepRow: View {
    let title: String
    let value: String
    var isRecorded = true
    var isLast = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isRecorded ? MMInk.text : Color.clear)
                    .overlay(Circle().strokeBorder(isRecorded ? Color.clear : MMInk.secondary.opacity(0.6), lineWidth: 1.25))
                    .frame(width: 9, height: 9)
                    .padding(.top, 5)
                if !isLast {
                    Rectangle().fill(MMInk.separator).frame(width: 1.25).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).mmFont(13, .medium).foregroundStyle(MMInk.secondary)
                Text(value).mmFont(15.5).foregroundStyle(isRecorded ? MMInk.text : MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 14)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// A light-surface photo row label for a native PhotosPicker (the picker itself stays system).
struct MMPhotoPickerLabel: View {
    let title: String
    var icon: String = "photo.on.rectangle"
    var isBusy = false

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isBusy { ProgressView().controlSize(.small).tint(MMInk.secondary) }
                else { Image(systemName: icon).font(.system(size: 16)).foregroundStyle(MMInk.text.opacity(0.75)) }
            }
            .frame(width: 24)
            Text(title).mmFont(16).foregroundStyle(MMInk.text)
            Spacer(minLength: 8)
            Image(systemName: "plus").font(.system(size: 13, weight: .semibold)).foregroundStyle(MMInk.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: MMMetrics.rowHeight, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Toast on a light sheet

extension View {
    /// The proof toast (same message / presenter) drawn for a light sheet: a calm MMNotice at the top.
    func mmLightToast(message: MMProofToastMessage?, isVisible: Bool) -> some View {
        overlay(alignment: .top) {
            if isVisible, let message {
                MMNotice(message: [message.title, message.message].compactMap { $0 }.joined(separator: ". "),
                         tone: message.kind.lightTone)
                    .padding(.horizontal, MMMetrics.inset)
                    .padding(.top, 8)
                    .environment(\.colorScheme, .light)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

extension MMProofToastMessage.Kind {
    var lightTone: MMNotice.Tone {
        switch self {
        case .success: .success
        case .warning: .warning
        case .danger: .error
        case .info: .info
        }
    }
}
