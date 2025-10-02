from enum import Enum


class MatchingCriteriaEnum(str, Enum):
    TOPIC = "topic"
    DIFFICULTY = "difficulty"
    LANGUAGE = "language"
