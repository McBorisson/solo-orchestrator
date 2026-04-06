# Platform & Pipeline Intake Script — v2 Concept

## Problem

The framework's auto-discovery relies on metadata markers in template files (e.g., CI templates need a `platforms` field to indicate which platforms they support). If a user drops a new file into `templates/pipelines/ci/` or `docs/platform-modules/` without the correct markers, auto-discovery silently misses the association. The user wouldn't know until they run init.sh and notice a language missing from a platform's list.

This is a "forgot to update the second file" problem. The current extensibility promise is "drop a file, it works." With platform-language filtering, that promise becomes "drop a file AND tag it correctly, or it doesn't work." That's a regression in usability.

## Solution

An intake script that runs when adding new platforms or pipelines. It asks the right questions and writes the markers automatically.

### Adding a new platform

```bash
bash scripts/add-platform.sh
```

The script would:
1. Ask for the platform name (e.g., "azure-microservices")
2. Ask for a one-line description
3. Show the list of existing languages and ask which ones apply to this platform
4. Create a skeleton platform module at `docs/platform-modules/{name}.md` with standard section headers
5. Create a skeleton release pipeline at `templates/pipelines/release/{name}.yml` with placeholder tokens
6. Optionally create a tool-matrix entry at `templates/tool-matrix/{name}.json` for platform-specific tools
7. Update existing CI template markers to include the new platform where the user indicated
8. Verify: run a dry check showing what init.sh would offer for this platform

### Adding a new language/pipeline

```bash
bash scripts/add-language.sh
```

The script would:
1. Ask for the language name (e.g., "cpp")
2. Ask for a display name if different (e.g., "C++")
3. Show the list of existing platforms and ask which ones this language applies to
4. Ask for the test file pattern (e.g., `_test.cpp$`)
5. Ask for the source file extension (e.g., `cpp|hpp|h`)
6. Create a skeleton CI template at `templates/pipelines/ci/{name}.yml` with the platforms marker and standard structure
7. Remind the user to add language-specific case blocks to init.sh (or auto-generate them if we can templatize that)
8. Verify: run a dry check showing what init.sh would offer for this language

### Validation on init

Init.sh should also validate that every CI template has a `platforms` marker. If a template is missing the marker, warn during init:

```
[WARN] templates/pipelines/ci/cpp.yml has no platforms marker — it won't appear in platform-filtered language lists.
       Run: bash scripts/add-language.sh to configure it.
```

This catches files dropped in without the intake script.

## Design Decisions (for when we build this)

1. **Marker format in CI templates**: YAML comment at the top (`# platforms: web, desktop, mobile`) vs. a dedicated metadata YAML key. Comment is simpler and doesn't interfere with GitHub Actions parsing. Dedicated key is cleaner but might confuse Actions.

2. **Should the intake script modify init.sh?**: The language `case` blocks in init.sh (permissions, gitignore, test patterns, release vars) need entries for new languages. Options:
   - The intake script generates the case entries and inserts them (automated but fragile — parsing bash to inject code)
   - The intake script generates a separate data file that init.sh reads (cleaner but changes init.sh's architecture)
   - The intake script tells the user what to add manually (safest but defeats the purpose)

3. **Retroactive tagging**: When this script is introduced, existing CI templates won't have markers. The script should offer a one-time "tag all existing templates" mode that walks through each one and asks which platforms apply.

## Relationship to Current Work

This is a v2 feature. For the current session, we're implementing Option B (platforms marker in CI templates) and manually tagging the existing 9 templates. This intake script would be built later to ensure future additions are tagged correctly.
