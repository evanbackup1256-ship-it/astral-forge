# Luau conventions

Project-owned Luau uses the checked-in StyLua configuration: tabs, a 120-column target, expanded control flow, and consistent spacing. Require order stays unchanged. Vendor code and installed packages are excluded.

Module suites keep typed `__defs`, `__cache`, and `__loading` tables. Cache entries wrap the result so `nil` and `false` remain valid cached values. Resolve unknown members explicitly, detect recursive loading, and clear the loading flag after both successful and failed calls. Preserve the original error and return the member's existing public interface.

Standalone modules use Roblox's require cache. Factory modules continue to return factories; entry scripts continue to start the runtime. Avoid adding another loader layer when a file has one responsibility.

Keep exported types at module scope. Validate external inputs at the boundary. Give asynchronous requests a deadline, prevent duplicate submission, and ignore callbacks after disposal or a newer request. Dispose connections, timers, and temporary instances when their owner closes.

Player text describes the action, reward, or story. Keep implementation details in source comments and developer documentation. Preserve content identifiers, save keys, rewards, and progression requirements when editing wording.

Run `lune run scripts/verify_project.luau` and build the Rojo project after a refactor. The suite includes executed loader, request, profile-lock, economy, guild, and ranking checks. StyLua's `--verify` checks formatting against the original syntax tree.
