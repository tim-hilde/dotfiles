export default async ({ client }) => {
    return {
        name: "claude-retry-test",

        event: async ({ event }) => {
            console.log("EVENT:", event?.type)

            if (event?.type === "session.error") {
                const retry = event?.error?.headers?.["retry-after"]

                let message = "Claude request error detected"

                if (retry) {
                    const seconds = parseInt(retry, 10)
                    const h = Math.floor(seconds / 3600)
                    const m = Math.floor((seconds % 3600) / 60)

                    message = `Claude limit reached — retry in ${h}h ${m}m`
                }

                await client.tui.toast.show({
                    message,
                    variant: "warning"
                })

                console.error("[claude-retry-test]", message)
            }
        }
    }
}
