/// The key (or chord) the user holds to summon the lens.
///
/// Raw values are the persistence format for ``SettingsStore``; renaming a
/// case would silently reset every user's saved trigger, so treat them as API.
public enum TriggerKey: String, CaseIterable, Codable, Sendable {
    case controlOption = "control_option"
    case fnKey = "fn"
    case rightCommand = "right_command"
}
