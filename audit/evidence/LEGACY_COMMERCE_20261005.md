# Legacy commerce configuration

Created four developer products and four game passes through the signed-in Creator Dashboard for Astral Forge universe 10767559102. Authoritative IDs/prices are recorded in LEGACY_COMMERCE_IDS_20261005.json. Dashboard rows verified all four developer product names, IDs and prices and all four passes on sale at 399/499/349/299 Robux. Managed pricing left disabled, matching the existing catalog. Optional pass icons use Roblox defaults.

Updated SharedData MonetizationConfig in both the current worktree and the main checkout. Studio Edit cloned-module require confirmed all eight IDs synced with their original internal keys. Rewards/descriptions were preserved: 80 Stardust, 120000 Flux, one Overdrive boost, three cores; 12% production, 25% production, 35% capacity, selected-rarity auto-salvage with first-discovery protection.

Main receipt implementation resolves product ID, records PurchaseId to receipt ledger, grants through ProgressionService.ApplyReward, saves before PurchaseGranted, and does not regrant a recorded receipt. Pass ownership loads through MarketplaceService and the existing owned-pass bonuses/auto-salvage gate.

Actual Robux spending and real receipt redelivery have not been tested. This task does not publish the place to Roblox; the source change needs publication for live servers. No test purchase or user balance transaction performed.
