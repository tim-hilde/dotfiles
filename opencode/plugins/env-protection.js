export const EnvProtection = async ({ project, client, $, directory, worktree }) => {
    return {
        "tool.execute.before": async (input, output) => {
            if (input.tool === "read" && output.args.filePath.includes(".env")) {
                throw new Error("Do not read .env files")
            }
        },
    }
}

export default {
    id: "env-protection",
    server: EnvProtection,
    setup: async (ctx) => {
        await ctx.tool.hook("execute.before", (event) => {
            if (event.tool === "read" && event.input?.filePath?.includes(".env")) {
                throw new Error("Do not read .env files")
            }
        })
    },
}
