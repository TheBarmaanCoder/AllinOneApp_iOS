import FamilyControls
import Foundation

enum SelectionMerge {
    static func mergedSelection(
        groups: [StoredFocusGroup],
        extra: FamilyActivitySelection?
    ) throws -> FamilyActivitySelection {
        var result = FamilyActivitySelection()

        for group in groups {
            let decoded = try SelectionCodec.decode(group.selectionData)
            result.applicationTokens.formUnion(decoded.applicationTokens)
            result.categoryTokens.formUnion(decoded.categoryTokens)
            result.webDomainTokens.formUnion(decoded.webDomainTokens)
        }

        if let extra {
            result.applicationTokens.formUnion(extra.applicationTokens)
            result.categoryTokens.formUnion(extra.categoryTokens)
            result.webDomainTokens.formUnion(extra.webDomainTokens)
        }

        return result
    }
}
