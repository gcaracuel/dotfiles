import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setWorkingIndicator({
      frames: [
        ctx.ui.theme.fg("primary", "●"),
        ctx.ui.theme.fg("secondary", "•"),
        ctx.ui.theme.fg("accent", " ○ "),
        ctx.ui.theme.fg("secondary", "•"),
      ],
      intervalMs: 150,
    });
  });
}
