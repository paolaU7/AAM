from dataclasses import dataclass


@dataclass(frozen=True)
class WorkshopGroup:
    id: int
    name: str
