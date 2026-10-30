// Records this pi session for Rex's Fork Agent Session action (~/.config/rex/agent_fork.lua)
import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

export default function (pi) {
  if (!process.env.REX_BLOCK) {
    return;
  }
  const script = join(homedir(), ".config", "rex", "agent-session");

  // Also fires for /new, /resume and /fork
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode === "tui") {
      execFile(script, ["record", "pi", ctx.sessionManager.getSessionId()], () => {});
    }
  });
}
