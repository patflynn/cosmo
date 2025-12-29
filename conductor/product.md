# Product Guide: Cosmo

## Initial Concept
**Goal:** Automate and optimize the "Cosmo" NixOS infrastructure to reduce manual setup, enhance the Hyprland developer experience (approaching "Omarchy" parity), and finalize the media server stack, with a secondary focus on basic home automation (Unifi integration).

## Vision
To build a resilient, reproducible, and automated infrastructure that serves as both a high-performance development environment and a reliable home media server. The system should minimize maintenance overhead through strict automation while providing a polished, cohesive user experience on the desktop.

## Core Objectives
1.  **Automation First:** Drastically reduce manual bootstrapping and configuration steps.
2.  **Hyprland Polish:** Elevate the Hyprland window manager configuration to be visually consistent, minimalist, and functionally robust, matching the standards of "Omarchy."
3.  **Media & Home Services:** Solidify the media streaming stack and establish basic access to Unifi camera feeds.
4.  **Developer Experience:** Optimize dotfiles and tools for a seamless coding workflow.
5.  **Modularity & Composition:** Refactor configuration into reusable, composable modules to easily define new hosts.
6.  **Public Bootstrap:** Ensure the repository is structured and documented such that a third party could fork and bootstrap their own system.

## Key Features & Scope

### 1. Hyprland Workspace Optimization
*   **Aesthetic:** Minimalist, distraction-free design with unified theming (A & D).
*   **Functionality:** Support for critical daily workflows (browser, terminal, editor).
*   **Parity Target:** "Omarchy" (High standard of polish and integration).

### 2. Infrastructure Automation
*   **CI/CD:** Automated checks and potential deployment pipelines.
*   **Secrets:** Secure, automated management via Agenix.
*   **Provisioning:** minimize manual shell commands for new host setup.

### 3. Media & Home Services
*   **Media Stack:** Finalize configuration for stability and access.
*   **Home Automation:** Restricted scope - primarily focusing on accessing Unifi camera feeds.

### 4. Architectural Improvements
*   **Composable Modules:** Well-defined boundaries for services and roles (e.g., `desktop`, `server`, `media`).
*   **Bootstrap Script/Docs:** Clear, idempotent entry point for fresh installs.

## Target Audience
*   **Primary User:** Patrick Flynn (Developer, Administrator).
*   **Secondary User:** Open-source community members looking for a reference NixOS starter.
*   **Needs:** Stability, efficiency, aesthetics, low maintenance, and clarity.

## Success Metrics
*   Reduction in time-to-setup for a new machine or VM.
*   Subjective satisfaction with the Hyprland visual and functional consistency.
*   Reliable access to media and camera streams without manual intervention.
*   Ease of defining a new host configuration (measured by lines of unique code required).
*   Successful "clean room" bootstrap by a third party (or simulated).
