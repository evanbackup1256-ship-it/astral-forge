# Wheel layout and Argon synchronization

Removed the twenty overlapping prize models from the 3D wheel. Numbered colored sectors now remain clear, with prize artwork retained in the result card and names in the prize table.

The page measures its actual width, accounting for the UI scale, instead of allocating wheel space from the entire screen width. Two columns require at least 760 logical pixels of page space; narrower pages stack the spin controls under the wheel. The heading is shorter and spacing is larger.

Restarted the existing Argon server from this worktree on localhost:8000. Verified Argon delivered the updated wheel source to the confirmed main Studio, and that the casino visibility fix and new planning/VR modules remain present.

Validation: full project verification and Argon build passed. Read-only Studio render checks passed at 320×700, 720×320, 1024×768, and 1344×756 with no detected text overflow at top, middle, or bottom scroll positions. Desktop render was visually inspected. Studio returned to Edit mode; no publishing performed.
