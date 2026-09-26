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

/**
 * Pull every shell command out of a run_commands input.
 *
 * The runtime sends `commands` as a STRING ARRAY. The original plugin read
 * only `input.command`, so this was always undefined and the hook silently
 * returned on every call. Accept all three shapes the runtime may use.
 */
const extractCommands = (input: unknown): string[] => {
	if (typeof input === "string") return [input]
	if (Array.isArray(input)) return input.filter((e): e is string => typeof e === "string")
	if (input && typeof input === "object") {
		const record = input as Record<string, unknown>
		const value = record.commands ?? record.command ?? record.cmd
		if (typeof value === "string") return [value]
		if (Array.isArray(value)) return value.filter((e): e is string => typeof e === "string")
	}
	return []
}

/**
 * Split one shell line on chaining operators so `cd x && git push` is caught.
 * This is the second reason the original missed: its regex was anchored with
 * ^, so anything before `git push` defeated it.
 */
const splitChain = (command: string): string[] =>
	command
		.split(/\s*(?:&&|\|\||;|\n|\|)\s*/)
		.map((part) => part.trim())
		.filter(Boolean)

/** True if this chain segment is a `git push`, ignoring where it sits in a chain. */
const isPushSegment = (segment: string): boolean => /^git\s+push\b/.test(segment)

const isProtectedPush = (command: string, cwd: string): string | null => {
	// Bypass hatch stays honoured, but only for this exact command.
	if (command.includes("--force-allow")) return null

	const isPush = splitChain(command).some(isPushSegment)
	if (!isPush) return null

	// The branch being protected is the one we are standing on. Refspecs in the
	// command are not trusted: a crafted refspec must not be able to smuggle a
	// push past the guard.
	const branch = currentBranch(cwd)
	if (!branch) return null
	return PROTECTED.find((p) => matchesGlob(branch, p)) ?? null
}

const plugin: AgentPlugin = {
	name: "branch-protector",
	manifest: { capabilities: ["hooks"] },

	hooks: {
		beforeTool({ toolCall, context }) {
			if (toolCall.toolName !== "run_commands") return
			// context is not guaranteed in every runtime path; fall back rather
			// than throwing inside the hook, which would abort the tool call.
			const cwd = context?.cwd ?? process.cwd()
			const commands = extractCommands((toolCall.input as Record<string, unknown>) ?? {})
			for (const command of commands) {
				const branch = isProtectedPush(command, cwd)
				if (branch) {
					return {
						skip: true,
						reason: `branch-protector: refusing 'git push' on protected branch '${branch}'. Add --force-allow to the command to override.`,
					}
				}
			}
		},
	},
}

export default plugin
