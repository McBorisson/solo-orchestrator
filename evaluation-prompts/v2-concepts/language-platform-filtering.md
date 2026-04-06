# Language-Platform Filtering, JVM Naming & CDF Cleanup — Next Session

## Problem 1: No platform-language filtering

The language selection during init shows ALL available languages regardless of the selected platform. A user selecting "mobile" sees C#, Go, Rust, Python — languages that aren't typical mobile development choices. This creates confusion and allows invalid combinations.

### Expected behavior

After selecting a platform, only show languages that make sense for that platform:

| Platform | Valid Languages |
|----------|----------------|
| web | typescript, python, rust, go, csharp, java, dart, other |
| mobile | dart, swift, kotlin, typescript, other |
| desktop | python, typescript, csharp, swift, rust, go, java, other |

### Implementation approach

Options to evaluate:
- Add a `valid_languages` array to each platform's tool-matrix JSON file
- Add a `platforms` field to each CI template (similar to how tools have platform filters)
- Hard-code the mapping in init.sh (simplest but doesn't auto-discover)

The auto-discovery principle should be preserved — adding a new language or platform shouldn't require editing init.sh.

## Problem 2: Kotlin and Java show as "jvm"

The CI template is `jvm.yml` which covers both Kotlin and Java (both use Gradle). But `jvm` is what appears in the language selection menu. Users expect to see "kotlin" or "java", not "jvm".

### Expected behavior

The language selection should show "kotlin" and "java" as separate options. Both map to the same `jvm.yml` CI template. The selected language name ("kotlin" or "java") is stored in tool-preferences.json and used for language-specific case blocks (permissions, gitignore, test patterns, release vars).

### Implementation approach

Options to evaluate:
- Create `kotlin.yml` and `java.yml` as copies or symlinks of `jvm.yml`
- Add a language alias/mapping file (`templates/pipelines/ci/language-aliases.json`) that maps display names to CI template files
- Rename `jvm.yml` to `kotlin.yml` and add metadata inside the YAML that lists aliases

The init.sh `case "$LANGUAGE"` blocks already handle `kotlin|java)` as combined cases, so the downstream code is ready — it's just the CI template naming and auto-discovery that need fixing.

## Problem 3: Mobile tool resolution ignores language and OS context

When a user selects mobile + swift, the tool resolution still offers to install Android Studio. Swift is Apple-only — Android Studio is irrelevant. The reverse would be true for kotlin (Android-only — Xcode is irrelevant). Cross-platform languages (dart/Flutter, typescript/React Native) genuinely need both.

This is NOT a simple "filter by language" fix. The relationship is nuanced:

| Mobile Language | Needs Xcode | Needs Android Studio |
|----------------|-------------|---------------------|
| swift | Yes | No |
| kotlin | No | Yes |
| dart (Flutter) | Yes | Yes |
| typescript (React Native) | Yes | Yes |

Additionally, the tool matrix should be OS-aware for mobile build tools:
- Linux cannot run Xcode at all — it should not appear as installable
- Android Studio on Linux uses a different install path than macOS
- The `dev_os` filter exists in the tool matrix schema but may not be applied to mobile-specific tools

### DECISIONS REQUIRED (do not implement without Orchestrator input)

1. **Where should the language→tool mapping live?**
   - Option A: In the tool-matrix JSON — add a `languages` filter to each mobile tool entry (e.g., Android Studio gets `["dart", "kotlin", "typescript"]`, Xcode gets `["dart", "swift", "typescript"]`). This uses the existing filter infrastructure.
   - Option B: In a new mobile-language-tools.json mapping file — keeps tool definitions clean, adds a lookup layer.
   - Option C: In init.sh logic — quick but violates auto-discovery principle.
   - **Trade-off:** Option A is simplest and uses existing infrastructure. But it means the tool-matrix JSON encodes language knowledge, which could get stale if new mobile languages emerge. Option B is cleaner separation of concerns but adds a file. Option C is fastest but creates another init.sh maintenance point.

2. **What happens when the combination is invalid but not preventable?**
   - User selects mobile + python. Python isn't a mobile language (no native mobile framework). Do we:
     - Block it with an error?
     - Warn and continue (they might know something we don't — Kivy, BeeWare exist)?
     - Show it but deprioritize it in the language list?
   - **Trade-off:** Blocking is safest but opinionated. Warning respects user autonomy. The framework's philosophy has been "warn, don't block" for non-security concerns.

3. **Should the OS filter be a hard block or a warning for mobile tools?**
   - If a Linux user selects mobile + swift, should init.sh:
     - Refuse to proceed (swift/iOS can only be built on macOS)?
     - Warn but continue (user might be setting up CI that runs on macOS runners)?
   - **Trade-off:** Hard block prevents wasted time. Warning allows edge cases. The existing tool matrix has `dev_os` filters that silently exclude tools — it doesn't warn, it just doesn't show them.

4. **How do we handle cross-compilation setups?**
   - Flutter on macOS needs both Xcode AND Android Studio. On Linux it only needs Android Studio (can't build iOS on Linux). This means the same language (dart) has different tool requirements per OS.
   - **Current behavior:** The tool matrix can filter by `dev_os` per tool. We need to verify this is applied correctly for mobile tools.

## Testing checklist

After implementing:
- [ ] Mobile platform shows dart, swift, kotlin, typescript (not csharp, python, rust, go)
- [ ] Desktop platform shows appropriate languages
- [ ] Web platform shows all web-capable languages
- [ ] Selecting "kotlin" produces correct CI pipeline, gitignore, test patterns, release vars
- [ ] Selecting "java" produces correct CI pipeline (same jvm template), correct gitignore, test patterns
- [ ] Adding a new language to a platform only requires adding a file, not editing init.sh
- [ ] tool-preferences.json stores "kotlin" not "jvm"
- [ ] Mobile + swift does NOT offer Android Studio installation
- [ ] Mobile + kotlin does NOT offer Xcode installation
- [ ] Mobile + dart offers BOTH Xcode and Android Studio (cross-platform)
- [ ] Mobile + typescript offers BOTH (React Native is cross-platform)
- [ ] Linux + mobile does NOT show Xcode as installable
- [ ] Linux + mobile + dart only offers Android Studio (can't build iOS on Linux)
- [ ] macOS + mobile + dart offers both Xcode and Android Studio
- [ ] Invalid combo (mobile + python) produces a warning, not a hard block

## Problem 4: CDF detect-profile.sh displays profile list when stdin is piped

When solo-orchestrator calls the CDF init with a piped profile name (`echo "desktop-app" | bash .../init.sh`), the CDF's `detect-profile.sh` correctly reads the piped value and auto-selects the profile. However, it still displays the "No recognized project signals found" message and the full profile list via stderr before accepting the piped input. This looks like an interactive prompt to the user even though no input is required.

### Current behavior
```
=== Installing Framework ===
No recognized project signals found.

Available profiles:
  - desktop-app: Desktop applications...
  - mobile-app: Native or cross-platform...
  - web-api: Web APIs...
  - web-app: Full-stack web applications...
```
The user sees this and thinks they need to choose, but the script already accepted the piped value and continued.

### Expected behavior
When stdin is not a terminal (`[ -t 0 ]` is false), suppress the profile list display and the "No recognized project signals" message. Just accept the piped input silently.

### Fix location
This is a CDF fix, not a solo-orchestrator fix. In `~/.claude-dev-framework/scripts/detect-profile.sh`:
- Wrap the `echo "No recognized project signals found"` and profile list display in `if [ -t 0 ]; then`
- Wrap the `echo "Detected signals..."` and suggestion display in the same check
- The `read` itself should still work from pipe — just suppress the decorative stderr output

### Testing
- [ ] CDF init via pipe shows no profile list (silent auto-selection)
- [ ] CDF init via terminal (direct run) still shows profile list and prompt
- [ ] Profile is correctly selected in both cases
