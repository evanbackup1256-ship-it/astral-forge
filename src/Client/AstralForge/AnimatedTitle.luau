local exports = {}
-- Player titles now render through the HyperText vendor module (real per-character motion,
-- gradients, and particle effects) instead of the old color/stroke-only glyph tricks -- see
-- HyperTextHost.tsx for the renderer and per-kind markup. Kept as a re-export so ChatView.tsx and
-- CommandView.tsx don't need to change their import path.
local _HyperTextHost = require(script.Parent.HyperTextHost)
exports.AnimatedTitle = _HyperTextHost.AnimatedTitle
exports.AnimatedTitlePreview = _HyperTextHost.AnimatedTitlePreview
exports.darkTitlePlate = _HyperTextHost.darkTitlePlate
exports.parseFx = _HyperTextHost.parseFx
exports.titleFxAccent = _HyperTextHost.titleFxAccent
exports.TITLE_FX_KINDS = _HyperTextHost.TITLE_FX_KINDS
return exports
