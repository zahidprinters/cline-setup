import { execSync } from "node:child_process"
import type { AgentPlugin } from "@cline/sdk"

const PROTECTED = ["main", "master", "release/*"]

const matchesGlob = (branch: string, pattern: string): boolean => {
	if (!pattern.includes("*")) return branch === pattern
	const regex = new RegExp("^" + pattern.replace(/\*/g, ".*") + "$")
	return regex.test(branch)
}

const currentBranch = (cwd: string): string | null => {
	try {
		return execSync("git rev-parse --abbrev-ref HEAD", { cwd, encoding: "utf8" }).trim()
	} catch {
		return null
	}
}

const isProtectedPush = (command: string, cwd: string): string | null => {
	if (!/^\s*git\s+push\b/.test(command)) return null
	if (command.includes("--force-allow")) return null
	const branch = currentBranch(cwd)
	if (!branch) return null
	const hit = PROTECTED.find((p) => matchesGlob(branch, p))
	return hit ? branch : null
}

const plugin: AgentPlugin = {
	name: "branch-protector",
	manifest: { capabilities: ["hooks"] },

	hooks: {
		beforeTool({ toolCall, context }) {
			if (toolCall.toolName !== "run_commands") return
			const input = toolCall.input as { command?: string } | undefined
			const command = input?.command
			if (!command) return
			const branch = isProtectedPush(command, context.cwd)
			if (!branch) return
			return {
				skip: true,
				reason: `branch-protector: refusing 'git push' on protected branch '${branch}'. Add --force-allow to the command to override.`,
			}
		},
	},
}

export default plugin
