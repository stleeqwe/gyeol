// 결 (Gyeol) — Open Source Licenses (Acknowledgments)
// 결_디자인시스템_v1 §8.3

import SwiftUI

public struct AcknowledgmentsScreen: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .gyeolXL) {
                ForEach(LicenseEntry.all) { entry in
                    LicenseSection(entry: entry)
                }
                Spacer().frame(height: .gyeolXL)
            }
            .padding(.gyeolLG)
        }
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .navigationTitle("Open Source Licenses")
        .gyNavigationBarTitleDisplayModeInline()
        .gyTrackAppear("AcknowledgmentsScreen")
    }
}

private struct LicenseSection: View {
    let entry: LicenseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.name)
                .font(.gyeolTitle3)
                .foregroundColor(.gyeolTextPrimary)
            if let url = entry.homepage {
                Text(url)
                    .font(.gyeolCaption2)
                    .foregroundColor(.gyeolTextTertiary)
            }
            Text(entry.licenseTitle)
                .font(.gyeolCaption1)
                .foregroundColor(.gyeolTextSecondary)
            Text(entry.licenseBody)
                .font(.gyeolCaption2)
                .foregroundColor(.gyeolTextSecondary)
                .lineSpacing(4)
                .padding(.top, .gyeolXS)
            Divider().background(Color.gyeolDivider).padding(.top, 12)
        }
    }
}

private struct LicenseEntry: Identifiable {
    let id = UUID()
    let name: String
    let homepage: String?
    let licenseTitle: String
    let licenseBody: String

    static let all: [LicenseEntry] = [
        LicenseEntry(
            name: "Pretendard",
            homepage: "github.com/orioncactus/pretendard",
            licenseTitle: "SIL Open Font License 1.1",
            licenseBody: """
            Copyright © Kil Hyung-jin. Licensed under the SIL Open Font License, Version 1.1.
            This license is available with a FAQ at: https://openfontlicense.org
            """
        ),
        LicenseEntry(
            name: "Supabase Swift SDK",
            homepage: "github.com/supabase/supabase-swift",
            licenseTitle: "MIT License",
            licenseBody: """
            Copyright © Supabase, Inc. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction.
            """
        ),
        LicenseEntry(
            name: "Swift Crypto / Foundation",
            homepage: "github.com/apple/swift-crypto",
            licenseTitle: "Apache License 2.0",
            licenseBody: """
            Copyright © Apple Inc. and the Swift project authors. Licensed under the Apache License, Version 2.0.
            """
        ),
    ]
}
