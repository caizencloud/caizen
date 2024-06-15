# -*- coding: utf-8 -*-
from datetime import datetime
from pydantic import BaseModel
from typing import List, Any


class CypherQuery(BaseModel):
    query: str

class ChangeSet(BaseModel):
    type: str
    date: datetime
    assets: List[Any]
    threat: float
class AttackPath(BaseModel):
    threat: float