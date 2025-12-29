# Product Guidelines: Cosmo

## Visual Identity
*   **Theme Palette:** Soft, matte, and eye-friendly. prioritizing schemes like **Nord, Gruvbox, or Dracula**.
    *   *Rationale:* Reduces eye strain during long coding sessions and maintains a professional, understated aesthetic.
*   **Interface Style:** Minimalist and Flat. Avoid excessive gradients, shadows, or skeuomorphism.
*   **Typography:** Monospace fonts for all code and terminal interfaces (e.g., JetBrains Mono, Fira Code). Clean sans-serif for UI elements.

## User Experience (UX) Principles
*   **Distraction-Free Core:** The workspace should prioritize the content (code, media) over chrome.
*   **Information Accessibility:**
    *   **Status Bars:** "Always Visible" by default to provide immediate system context (time, battery, workspace), but **must include a toggle** for a completely immersive mode.
    *   **Notifications:** Urgent-only by default. Silent or batched for non-critical updates.
*   **Keyboard-Centric:** Primary interaction model is keyboard-driven (Vim motions, tiling manager shortcuts). Mouse usage is secondary.

## Engineering & Architectural Standards
*   **Modularity Strategy:**
    *   **Balanced Approach:** Avoid over-engineering. Use "Convention over Configuration" for directory structures, but ensure critical complex modules have clear comments ("Literate Configuration").
    *   **Composable Roles:** Define host capabilities (e.g., `gaming`, `server`, `laptop`) as composable mixins rather than monolithic host files.
*   **Bootstrap-Readiness:**
    *   **Idempotency:** All scripts and configurations must be safe to run multiple times without side effects.
    *   **Documentation:** Maintain a "Golden Path" guide for bootstrapping a fresh system in `docs/`.

## Tone & Voice (Documentation)
*   **Pragmatic:** Focus on the "how" and "why".
*   **Concise:** Avoid fluff.
*   **Inclusive:** Written to be understood by an intermediate Linux user, not just the author.
