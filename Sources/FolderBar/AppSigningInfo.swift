import Foundation
import Security

enum AppSigningInfo {
    static func summary() -> String {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return "Signing: (not an app bundle)"
        }

        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &staticCode)
        guard createStatus == errSecSuccess, let staticCode else {
            return "Signing: unknown"
        }

        let validityStatus = SecStaticCodeCheckValidityWithErrors(
            staticCode,
            SecCSFlags(rawValue: kSecCSBasicValidateOnly),
            nil,
            nil
        )
        guard validityStatus == errSecSuccess else {
            return "Signing: invalid"
        }

        var signingInfo: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInfo
        )

        guard infoStatus == errSecSuccess,
              let signingInfo = signingInfo as? [CFString: Any] else {
            return "Signing: unknown"
        }

        let teamID = signingInfo[kSecCodeInfoTeamIdentifier] as? String
        let certificateSummary = (signingInfo[kSecCodeInfoCertificates] as? [SecCertificate])
            .flatMap { $0.first }
            .flatMap { SecCertificateCopySubjectSummary($0) as String? }

        if let teamID {
            if let certificateSummary {
                return "Signing: \(certificateSummary) (\(teamID))"
            }
            return "Signing: Team \(teamID)"
        }

        return "Signing: ad-hoc"
    }
}

