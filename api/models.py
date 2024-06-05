# -*- coding: utf-8 -*-

from pydantic import BaseModel


class CypherQuery(BaseModel):
    query: str
