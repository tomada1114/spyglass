import SwiftUI

/// The design-token colors from `docs/design.md` §1, backed by the package
/// asset catalog so each carries its Any/Dark variant.
extension Color {
    static let brassPrimary = Color("brassPrimary", bundle: Bundle.module)
    static let brassDeep = Color("brassDeep", bundle: Bundle.module)
    static let brassMid = Color("brassMid", bundle: Bundle.module)
    static let brassBright = Color("brassBright", bundle: Bundle.module)
    static let stageBackground = Color("stageBackground", bundle: Bundle.module)
    static let stageWindowFront = Color("stageWindowFront", bundle: Bundle.module)
    static let stageWindowBack = Color("stageWindowBack", bundle: Bundle.module)
}
