# Generated configuration build reproduction

Running the configuration generator failed first with unsupported CrateExpansion/SharedData dependencies after shared-module bundling. Extended the build environment to resolve the actual shared factory and crate module. The full generator then completed: 2810 machines, 1408 research entries, 125 zones, 6720 grid upgrades, 300 seasons, 300 milestones, 4012 expeditions, maxZone 500000.

Regeneration produced floating-point differences in existing generated costs/production (for example 465000000 -> 464999999.9999996). Retained the existing checked-in generated artifact to avoid silently changing monetary rounding while validating the build tool. A scalar-equivalence/cost-rounding audit is still required before replacing it. The successful test output is archived separately and the generator supports an explicit output path for future verification.
