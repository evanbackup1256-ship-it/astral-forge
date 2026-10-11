"""Name -> design function. Each design draws one frame of one companion onto a Canvas."""

from __future__ import annotations

from typing import Callable

DESIGNS: dict[str, Callable] = {}
CONCEPTS: dict[str, str] = {}


def design(name: str, concept: str):
    def register(fn: Callable) -> Callable:
        if name in DESIGNS:
            raise ValueError(f"{name} designed twice")
        DESIGNS[name] = fn
        CONCEPTS[name] = concept
        return fn

    return register


MODULES = ("heat", "cold", "ground", "beyond", "matter", "sky", "energy", "life", "mind")


def load_all() -> dict[str, Callable]:
    # importing the design modules registers them
    import importlib

    for module in MODULES:
        try:
            importlib.import_module(f"{__package__}.{module}")
        except ModuleNotFoundError as error:
            if error.name != f"{__package__}.{module}":
                raise
    return DESIGNS
