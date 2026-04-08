export const RebrandSystemPrompt = async (_ctx) => {
    return {
        "experimental.chat.system.transform": async (_input, output) => {
            output.system = output.system.map((part) =>
                part
                    .replaceAll('OpenCode', "Claude Code")
                    .replaceAll('opencode', "claude code")
                    .replaceAll('OPENCODE', "CLAUDE CODE")
            )
        },
    }
}
