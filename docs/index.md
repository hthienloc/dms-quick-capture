# DMS Quick Capture Documentation

Welcome to the official developer and user documentation for **DMS Quick Capture**, a composite screenshot and annotation plugin for DankMaterialShell (DMS).

---

## Document Index

1. **[User Guide](user-guide.md)**
   - Capture workflow, annotation tools, shortcuts, floating images, and IPC.

2. **[System Architecture](architecture.md)**
   - Overview of the composite plugin lifecycle.
   - Roles of the Daemon, Widget, and Modal.
   - IPC and focus management under Wayland.

3. **[Annotation Engine](annotation-engine.md)**
   - Canvas coordinate systems and drawing pipeline.
   - Vector tools and presets.
   - Background system (solid, gradient, aspect ratio, padding).
   - Magnifier and Zoom callout implementation.

4. **[Rust Backend Architecture](rust-backend-architecture.md)**
   - Wayland capture flow and output composition.
   - Selector state, coordinate spaces, scaling, and viewporter behavior.
   - Scroll capture, preview synchronization, persistence, and fallbacks.

5. **[IPC and Settings Reference](ipc-and-settings.md)**
   - Detailed IPC commands registry with usage examples.
   - Keyboard shortcuts & Shift constraints list.
   - Configuration schema (`plugin.json` settings).

6. **[Developer & Contributor Guide](developer-guide.md)**
   - Code conventions, directory layout, and styling.
   - Tutorial: Adding a new drawing tool.
   - Debugging, profiling, and QML testing techniques.

7. **[AI Implementation Guide](ai-guide.md)**
   - Internal technical map for AI agents.
   - Canvas reactivity rules, popout clipping fixes, and coordinate mapping formulas.
