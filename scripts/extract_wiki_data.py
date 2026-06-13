#!/usr/bin/env python3

from __future__ import annotations

import json
import math
import re
import shutil
import sqlite3
import sys
import zipfile
from dataclasses import dataclass, field, replace
from pathlib import Path
from typing import Any, Iterable

from PIL import Image


PLACEHOLDER_RE = re.compile(r"\{(\d+)\}")
ANY_PLACEHOLDER_RE = re.compile(r"\{[^}]+\}")
MARKUP_TAG_RE = re.compile(r"</?(?:b|br|color|i|size|sprite|u)(?:=[^>]+)?>", re.I)
FUNC_RE = re.compile(r"(?ms)^\s*(?P<decl>[A-Za-z_]\w*)\s+(?P<name>[A-Za-z_]\w*)\s*\{(?P<body>.*?)\}")
CALL_RE = re.compile(r"([A-Za-z_]\w*)\s*\((.*?)\)\s*", re.S)
CONST_TEXT_RE = re.compile(r"Text\(\s*return\s*,\s*(['\"])(?P<val>.*?)\1\s*\)\s*;?", re.S)
HERO_ID_RE = re.compile(r"^[a-z]+_hero_(\d+)$", re.I)
GAME_VERSION_RE = re.compile(r"\b\d+\.\d+\.\d+\b")

# Edit these in Spyder, then click Run.
SETTINGS = {
    "game_path": "/Users/f2pgod/Library/Application Support/CrossOver/Bottles/steam_win/drive_c/Program Files (x86)/Steam/steamapps/common/Heroes of Might and Magic Olden Era",
    "output_dir": "./scripts/output",
    "app_db_path": "./assets/db/wiki.sqlite",
    "app_images_dir": "./assets/images",
    "locale": "english",
    "clean_output_dir": True,
    "clean_app_images_dir": True,
    "fail_on_missing_icon": False,
    "fail_on_unresolved_text": False,
}


APP_IMAGE_MAX_DIMENSION = 128

KNOWN_ICON_PATTERNS = {
    "hp": ["Property_1_Icon_Stats_Hp__*.png"],
    "attack": ["Property_1_Icon_Stats_Attack__*.png"],
    "defense": ["Property_1_Icon_Stats_Defence__*.png"],
    "damage": ["Property_1_Icon_Stats_Damage__*.png"],
    "initiative": ["Property_1_iIcon_Stats_Initiative__*.png"],
    "speed": ["Property_1_Icon_Stats_Speed__*.png"],
    "luck": ["Property_1_Icon_Stats_Luck__*.png"],
    "morale": ["Property_1_Icon_Stats_Morale__*.png"],
    "experience": ["Property_1_Icon_Stats_Experience__*.png"],
    "squadValue": ["Property_1_Icon_Stats_Count__*.png"],
    "energy": ["Property_1_Icon_Stats_Energy__*.png"],
    "gold": ["Icon_Resource_Gold__*.png"],
    "lawPoints": ["Icon_LawsPoint__*.png"],
    "wood": ["Icon_Resource_Wood__*.png"],
    "ore": ["Icon_Resource_Iron__*.png"],
    "dust": ["dust_64__*.png"],
    "starDust": ["starDust_64__*.png"],
    "mercury": ["Icon_Resource_Mercury__*.png"],
    "crystals": ["Icon_Resource__rystal__*.png"],
    "gemstones": ["Icon_Resource_GemStone__*.png"],
    "graal": ["Icon_Resource_Graal__*.png"],
    "cooldown": ["tooltip_icon_cooldown__*.png"],
    "faction.human": ["human_big_icon__*.png"],
    "faction.demon": ["demon_big_icon__*.png"],
    "faction.undead": ["undead_big_icon__*.png"],
    "faction.nature": ["nature_big_icon__*.png"],
    "faction.dungeon": ["dungeon_big_icon__*.png"],
    "faction.unfrozen": ["unfrozen_big_icon__*.png"],
}


class ExtractionError(RuntimeError):
    pass


class ResolutionError(ExtractionError):
    pass


def to_number(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return 0.0
    return 0.0


def unwrap_value(value: Any) -> Any:
    if isinstance(value, dict) and "v" in value:
        return value["v"]
    return value


def json_as_string(value: Any) -> str | None:
    value = unwrap_value(value)
    if value is None:
        return None
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        if isinstance(value, float) and value.is_integer():
            return str(int(value))
        return format(value, "g")
    if isinstance(value, str):
        return value
    return None


def json_path_get(root: Any, path: str) -> Any:
    if root is None or not path:
        raise KeyError(path)
    value = root
    i = 0
    while i < len(path):
        dot = path.find(".", i)
        bracket = path.find("[", i)
        if bracket != -1 and (dot == -1 or bracket < dot):
            key = path[i:bracket]
            if key:
                if not isinstance(value, dict) or key not in value:
                    raise KeyError(path)
                value = value[key]
            close = path.find("]", bracket + 1)
            if close == -1:
                raise KeyError(path)
            idx = int(path[bracket + 1:close])
            if not isinstance(value, list) or idx >= len(value):
                raise KeyError(path)
            value = value[idx]
            i = close + 1
            if i < len(path) and path[i] == ".":
                i += 1
        else:
            key = path[i:] if dot == -1 else path[i:dot]
            if key:
                if not isinstance(value, dict) or key not in value:
                    raise KeyError(path)
                value = value[key]
            i = len(path) if dot == -1 else dot + 1
    return value


def sanitize_path_component(text: str) -> str:
    safe = re.sub(r"[^A-Za-z0-9._/-]+", "_", text.replace("\\", "/").strip("/"))
    return safe.strip("/") or "unnamed"


def deep_copy_json(value: Any) -> Any:
    return json.loads(json.dumps(value))


def json_blob(value: Any) -> str | None:
    if value is None:
        return None
    return json.dumps(value, ensure_ascii=True)


def sql_scalar(value: Any) -> Any:
    if value is None or isinstance(value, (str, int, float)):
        return value
    return None


@dataclass(frozen=True)
class ResolutionContext:
    locale: str
    unit_id: str | None = None
    ability_index: int | None = None
    is_active_ability: bool | None = None
    hero_specialization_id: str | None = None
    hero_ability_id: str | None = None
    skill_id: str | None = None
    sub_skill_id: str | None = None
    skill_level: int | None = None
    buff_id: str | None = None
    buff_stacks: int | None = None
    buff_spell_power: int | None = None
    item_id: str | None = None
    item_level: int | None = None
    item_set_id: str | None = None
    magic_id: str | None = None
    magic_level: int | None = None
    fraction_id: str | None = None
    law_id: str | None = None
    law_level: int | None = None
    map_object_id: str | None = None


@dataclass
class ScriptSettings:
    assume_baseline_stacks_when_missing: bool = False
    assume_zero_for_missing_numeric_config: bool = False
    assume_hero_level_when_missing: bool = True
    hero_level_baseline: float = 1.0


@dataclass(frozen=True)
class AppImageJob:
    relative_path: str
    max_dimension: int


class CoreArchive:
    def __init__(self, streaming_assets_root: Path):
        self.streaming_assets_root = streaming_assets_root
        self.core_zip_path = streaming_assets_root / "Core.zip"
        if not self.core_zip_path.exists():
            raise ExtractionError(f"Core.zip not found at {self.core_zip_path}")
        self.zip = zipfile.ZipFile(self.core_zip_path)
        self.entries = {entry.filename: entry for entry in self.zip.infolist()}

    def close(self) -> None:
        self.zip.close()

    def read_json(self, entry_name: str) -> Any:
        with self.zip.open(entry_name) as handle:
            return json.load(handle)

    def read_text(self, entry_name: str) -> str:
        with self.zip.open(entry_name) as handle:
            return handle.read().decode("utf-8-sig")

    def iter_entries(self, prefix: str, suffix: str = ".json") -> Iterable[str]:
        for name in sorted(self.entries):
            if name.startswith(prefix) and name.endswith(suffix):
                yield name

    def array_entries(self, prefix: str) -> list[tuple[str, list[dict[str, Any]]]]:
        results: list[tuple[str, list[dict[str, Any]]]] = []
        for entry_name in self.iter_entries(prefix):
            try:
                payload = self.read_json(entry_name)
            except json.JSONDecodeError as exc:
                raise ExtractionError(f"Failed to parse JSON from {entry_name}: {exc}") from exc
            array = payload.get("array")
            if isinstance(array, list):
                records = [item for item in array if isinstance(item, dict)]
                results.append((entry_name, records))
        return results


class LangIndex:
    def __init__(self, streaming_assets_root: Path, locale: str, fallback_to_english: bool = True):
        self.streaming_assets_root = streaming_assets_root
        self.locale = locale or "english"
        self.fallback_to_english = fallback_to_english
        self.texts: dict[str, str] = {}
        self.args_by_sid: dict[str, list[str]] = {}

    def load(self, archive: CoreArchive) -> None:
        self.texts.clear()
        self.args_by_sid.clear()
        self._load_texts_for_locale(archive, self.locale, overwrite=True)
        if self.fallback_to_english and self.locale.lower() != "english":
            self._load_texts_for_locale(archive, "english", overwrite=False)
        args_dir = self.streaming_assets_root / "Lang" / "args"
        if args_dir.is_dir():
            for file_path in sorted(args_dir.glob("*.json")):
                payload = json.loads(file_path.read_text(encoding="utf-8"))
                self._load_args_payload(payload)
        else:
            for entry_name in archive.iter_entries("Lang/args/"):
                payload = archive.read_json(entry_name)
                self._load_args_payload(payload)

    def _load_texts_for_locale(self, archive: CoreArchive, locale: str, overwrite: bool) -> None:
        texts_dir = self.streaming_assets_root / "Lang" / locale / "texts"
        if texts_dir.is_dir():
            for file_path in sorted(texts_dir.glob("*.json")):
                payload = json.loads(file_path.read_text(encoding="utf-8"))
                self._load_text_payload(payload, overwrite)
            return
        prefix = f"Lang/{locale}/texts/"
        for entry_name in archive.iter_entries(prefix):
            payload = archive.read_json(entry_name)
            self._load_text_payload(payload, overwrite)

    def _load_text_payload(self, payload: dict[str, Any], overwrite: bool) -> None:
        tokens = payload.get("tokens")
        if not isinstance(tokens, list):
            return
        for token in tokens:
            if not isinstance(token, dict):
                continue
            sid = token.get("sid")
            text = token.get("text")
            if isinstance(sid, str) and isinstance(text, str):
                if overwrite or sid not in self.texts:
                    self.texts[sid] = text

    def _load_args_payload(self, payload: dict[str, Any]) -> None:
        tokens_args = payload.get("tokensArgs")
        if not isinstance(tokens_args, list):
            return
        for token in tokens_args:
            if not isinstance(token, dict):
                continue
            sid = token.get("sid")
            args = token.get("args")
            if not isinstance(sid, str) or not isinstance(args, list):
                continue
            self.args_by_sid[sid] = [str(arg) for arg in args]

    def resolve_text(self, sid: str | None) -> str | None:
        if not sid:
            return None
        return self.texts.get(sid)

    def get_args(self, sid: str) -> list[str]:
        if sid in self.args_by_sid:
            return self.args_by_sid[sid]
        base_sid = self._try_get_base_sid(sid)
        if base_sid and base_sid in self.args_by_sid:
            return self.args_by_sid[base_sid]
        generated = self._try_generate_ability_duration_args(sid)
        if generated is not None:
            return generated
        generated = self._try_generate_faction_law_args(sid)
        if generated is not None:
            return generated
        return []

    def _try_generate_ability_duration_args(self, sid: str) -> list[str] | None:
        if not re.search(r"_ability_\d+_description$", sid, re.I):
            return None
        text = self.resolve_text(sid)
        if not text or "{0}" not in text:
            return None
        if not any(word in text.lower() for word in ("duration", "round", "turn")):
            return None
        return ["current_unit_ability_buff_duration|alt_text_ability_buff_duration_1"]

    def _try_generate_faction_law_args(self, sid: str) -> list[str] | None:
        if not re.search(r"^fraction_law_\w+_\d+_desc$", sid, re.I):
            return None
        text = self.resolve_text(sid)
        if not text or "{0}" not in text:
            return None
        placeholder_count = 0
        for match in re.finditer(r"\{(\d+)\}", text):
            placeholder_count = max(placeholder_count, int(match.group(1)) + 1)
        if placeholder_count <= 0:
            return None
        return [f"current_law_modInt_bonuses_{index}_parameters_1" for index in range(placeholder_count)]

    @staticmethod
    def _try_get_base_sid(sid: str) -> str | None:
        suffix_pairs = [
            ("_alt_2_desc", "_desc"),
            ("_alt_2_name", "_name"),
            ("_alt_desc", "_desc"),
            ("_alt_name", "_name"),
            ("_description_1", "_description"),
            ("_description", "_desc"),
            ("_desc_alt", "_desc"),
            ("_name_alt", "_name"),
        ]
        for variant, base in suffix_pairs:
            if sid.lower().endswith(variant.lower()):
                return sid[:-len(variant)] + base
        return None


class DbAccessor:
    def __init__(self, archive: CoreArchive):
        self.archive = archive
        self.unit_by_id: dict[str, dict[str, Any]] = {}
        self.buff_by_sid_or_id: dict[str, dict[str, Any]] = {}
        self.hero_specialization_by_id: dict[str, dict[str, Any]] = {}
        self.skill_by_id: dict[str, dict[str, Any]] = {}
        self.sub_skill_by_id: dict[str, dict[str, Any]] = {}
        self.side_buff_by_id: dict[str, dict[str, Any]] = {}
        self.ability_by_id: dict[str, dict[str, Any]] = {}
        self.obstacle_by_id: dict[str, dict[str, Any]] = {}
        self.item_by_id: dict[str, dict[str, Any]] = {}
        self.item_set_by_id: dict[str, dict[str, Any]] = {}
        self.magic_by_id: dict[str, dict[str, Any]] = {}
        self.trap_by_id: dict[str, dict[str, Any]] = {}
        self.building_by_id: dict[str, dict[str, Any]] = {}
        self.law_by_id: dict[str, dict[str, Any]] = {}
        self.map_object_by_id: dict[str, dict[str, Any]] = {}
        self._index_all()

    def _index_all(self) -> None:
        self._index_array("DB/units/units_logics/", self.unit_by_id, id_key="id")
        self._index_buffs()
        self._index_array("DB/heroes_specializations/", self.hero_specialization_by_id, id_key="id")
        self._index_array("DB/heroes_skills/skills/", self.skill_by_id, id_key="id")
        self._index_array("DB/heroes_skills/sub_skills/", self.sub_skill_by_id, id_key="id")
        self._index_array("DB/logic_side_buffs/", self.side_buff_by_id, id_key="id")
        self._index_array("DB/side_buffs/bonus_buff_infos/", self.side_buff_by_id, id_key="id")
        self._index_array("DB/heroes_abilities/heroes_abilities_base/", self.ability_by_id, id_key="id")
        self._index_array("DB/field_objects/obstacles/", self.obstacle_by_id, id_key="id")
        self._index_array("DB/items/", self.item_by_id, id_key="id")
        self._index_array("DB/items/item_sets/", self.item_set_by_id, id_key="id")
        self._index_array("DB/magics/", self.magic_by_id, id_key="id")
        self._index_array("DB/field_objects/traps/", self.trap_by_id, id_key="id")
        self._index_buildings()
        self._index_laws()
        self._index_map_objects()

    def _index_array(self, prefix: str, target: dict[str, dict[str, Any]], id_key: str) -> None:
        for _, records in self.archive.array_entries(prefix):
            for record in records:
                key = record.get(id_key)
                if isinstance(key, str) and key:
                    target[key] = deep_copy_json(record)

    def _index_buffs(self) -> None:
        for _, records in self.archive.array_entries("DB/buffs/"):
            for record in records:
                sid = record.get("sid")
                record_id = record.get("id")
                if isinstance(sid, str) and sid:
                    self.buff_by_sid_or_id[sid] = deep_copy_json(record)
                if isinstance(record_id, str) and record_id:
                    self.buff_by_sid_or_id[record_id] = deep_copy_json(record)

    def _index_buildings(self) -> None:
        for _, records in self.archive.array_entries("DB/objects_logic/cities/"):
            for record in records:
                sid = record.get("sid")
                if isinstance(sid, str) and sid:
                    self.building_by_id[sid] = deep_copy_json(record)

    def _index_laws(self) -> None:
        for entry_name, records in self.archive.array_entries("DB/fractions_laws/"):
            if "fractions_laws_table_" not in entry_name:
                continue
            for record in records:
                law_id = record.get("id")
                if isinstance(law_id, str) and law_id:
                    self.law_by_id[law_id] = deep_copy_json(record)

    def _index_map_objects(self) -> None:
        for entry_name, records in self.archive.array_entries("DB/map/objects/"):
            lower = entry_name.lower()
            if not lower.endswith("3_resources.json") and not lower.endswith("4_interactables.json") and not lower.endswith("6_artifacts.json"):
                continue
            for record in records:
                map_object_id = record.get("id")
                if isinstance(map_object_id, str) and map_object_id:
                    self.map_object_by_id[map_object_id] = deep_copy_json(record)

    def get_unit(self, unit_id: str) -> dict[str, Any] | None:
        return self.unit_by_id.get(unit_id)

    def get_buff(self, buff_id: str) -> dict[str, Any] | None:
        return self.buff_by_sid_or_id.get(buff_id)

    def get_hero_specialization(self, spec_id: str) -> dict[str, Any] | None:
        return self.hero_specialization_by_id.get(spec_id)

    def get_skill(self, skill_id: str) -> dict[str, Any] | None:
        return self.skill_by_id.get(skill_id)

    def get_sub_skill(self, sub_skill_id: str) -> dict[str, Any] | None:
        return self.sub_skill_by_id.get(sub_skill_id)

    def get_side_buff(self, buff_id: str) -> dict[str, Any] | None:
        return self.side_buff_by_id.get(buff_id)

    def get_hero_ability(self, ability_id: str) -> dict[str, Any] | None:
        return self.ability_by_id.get(ability_id)

    def get_ability(self, ability_id: str) -> dict[str, Any] | None:
        return self.ability_by_id.get(ability_id)

    def get_obstacle(self, obstacle_id: str) -> dict[str, Any] | None:
        return self.obstacle_by_id.get(obstacle_id)

    def get_item(self, item_id: str) -> dict[str, Any] | None:
        return self.item_by_id.get(item_id)

    def get_item_set(self, item_set_id: str) -> dict[str, Any] | None:
        return self.item_set_by_id.get(item_set_id)

    def get_magic(self, magic_id: str) -> dict[str, Any] | None:
        return self.magic_by_id.get(magic_id)

    def get_trap(self, trap_id: str) -> dict[str, Any] | None:
        return self.trap_by_id.get(trap_id)

    def get_building(self, building_id: str) -> dict[str, Any] | None:
        return self.building_by_id.get(building_id)

    def get_law(self, law_id: str) -> dict[str, Any] | None:
        return self.law_by_id.get(law_id)

    def get_map_object(self, map_object_id: str) -> dict[str, Any] | None:
        return self.map_object_by_id.get(map_object_id)


@dataclass
class ScriptValue:
    numeric_value: float | None = None
    string_value: str | None = None

    @property
    def is_numeric(self) -> bool:
        return self.numeric_value is not None

    def as_double(self) -> float:
        if self.numeric_value is not None:
            return self.numeric_value
        return to_number(self.string_value)

    def __str__(self) -> str:
        if self.numeric_value is not None:
            if self.numeric_value.is_integer():
                return str(int(self.numeric_value))
            return format(self.numeric_value, "g")
        return self.string_value or ""


class ScriptEnvironment:
    def __init__(self) -> None:
        self.variables: dict[str, ScriptValue] = {}

    def set(self, name: str, value: Any) -> None:
        if isinstance(value, ScriptValue):
            self.variables[name] = value
        elif isinstance(value, (int, float)):
            self.variables[name] = ScriptValue(numeric_value=float(value))
        else:
            self.variables[name] = ScriptValue(string_value=str(value))

    def try_get(self, name: str) -> ScriptValue | None:
        return self.variables.get(name)

    def resolve_value(self, token: str) -> ScriptValue:
        if token in self.variables:
            return self.variables[token]
        unquoted = token
        if len(unquoted) >= 2 and unquoted[0] == '"' and unquoted[-1] == '"':
            unquoted = unquoted[1:-1]
        try:
            return ScriptValue(numeric_value=float(unquoted))
        except ValueError:
            return ScriptValue(string_value=unquoted)


@dataclass
class ScriptStatement:
    op: str
    args: list[str]


@dataclass
class ScriptFunction:
    name: str
    declared_type: str
    body: list[ScriptStatement] = field(default_factory=list)


class ScriptRegistry:
    def __init__(self, archive: CoreArchive):
        self.functions: dict[str, ScriptFunction] = {}
        for entry_name in archive.iter_entries("DB/info/", suffix=".script"):
            self._parse_file(archive.read_text(entry_name))

    def _parse_file(self, text: str) -> None:
        for match in FUNC_RE.finditer(text):
            function = ScriptFunction(
                name=match.group("name").strip(),
                declared_type=match.group("decl").strip(),
            )
            body = match.group("body")
            for call_match in CALL_RE.finditer(body):
                function.body.append(ScriptStatement(call_match.group(1).strip(), split_args(call_match.group(2))))
            self.functions[function.name.lower()] = function

    def get(self, name: str) -> ScriptFunction | None:
        return self.functions.get(name.lower())


class InfoScriptIndex:
    def __init__(self, archive: CoreArchive):
        self.map: dict[str, str] = {}
        for entry_name in archive.iter_entries("DB/info/", suffix=".script"):
            content = archive.read_text(entry_name)
            for fn_match in re.finditer(r"string\s+(?P<name>[A-Za-z0-9_]+)\s*\{(?P<body>.*?)\}", content, re.S):
                function_name = fn_match.group("name")
                const_match = CONST_TEXT_RE.search(fn_match.group("body"))
                if const_match and function_name not in self.map:
                    self.map[function_name] = const_match.group("val")

    def get(self, func_name: str) -> str | None:
        return self.map.get(func_name)


def split_args(inner: str) -> list[str]:
    args: list[str] = []
    current: list[str] = []
    in_string = False
    quote = '"'
    i = 0
    while i < len(inner):
        ch = inner[i]
        if in_string:
            if ch == "\\" and i + 1 < len(inner):
                current.append(ch)
                current.append(inner[i + 1])
                i += 2
                continue
            if ch == quote:
                in_string = False
                current.append(ch)
                i += 1
                continue
            current.append(ch)
            i += 1
            continue
        if ch in ('"', "'"):
            in_string = True
            quote = ch
            current.append(ch)
            i += 1
            continue
        if ch == ",":
            args.append("".join(current).strip())
            current = []
            i += 1
            continue
        current.append(ch)
        i += 1
    tail = "".join(current).strip()
    if tail:
        args.append(tail)
    cleaned: list[str] = []
    for arg in args:
        if len(arg) >= 2 and arg[0] == arg[-1] and arg[0] in ('"', "'"):
            arg = arg[1:-1]
        cleaned.append(arg.strip())
    return cleaned


class ScriptInterpreter:
    def __init__(self, registry: ScriptRegistry, db: DbAccessor, settings: ScriptSettings | None = None):
        self.registry = registry
        self.db = db
        self.settings = settings or ScriptSettings()

    def try_evaluate(self, func_name: str, context: ResolutionContext) -> str | None:
        function = self.registry.get(func_name)
        if function is None:
            return None
        env = ScriptEnvironment()
        return_value: str | None = None
        for statement in function.body:
            if not self.execute_statement(statement, context, env, return_value_holder := {"value": return_value}):
                return None
            return_value = return_value_holder["value"]
        raw = return_value
        if raw is None:
            ret = env.try_get("return")
            raw = str(ret) if ret is not None else None
        if raw is None:
            return None
        if function.declared_type:
            try:
                num = float(raw)
            except ValueError:
                return raw
            return self._format_by_type(function.declared_type, num)
        return raw

    def execute_statement(self, statement: ScriptStatement, context: ResolutionContext, env: ScriptEnvironment, return_value_holder: dict[str, str | None]) -> bool:
        op = statement.op
        args = statement.args
        return (
            self._execute_arithmetic(op, args, env)
            or self._execute_unit(op, args, context, env)
            or self._execute_buff(op, args, context, env)
            or self._execute_item(op, args, context, env)
            or self._execute_magic(op, args, context, env)
            or self._execute_skill(op, args, context, env)
            or self._execute_hero(op, args, context, env)
            or self._execute_db(op, args, env)
            or self._execute_misc(op, args, context, env)
            or self._execute_control(op, args, context, env, return_value_holder)
            or self._execute_pattern(op, args, context, env)
        )

    @staticmethod
    def _format_by_type(declared_type: str, num: float) -> str:
        if declared_type == "modPercentNumeric":
            return str(round(abs(num) * 100))
        if declared_type == "modFloatPercentF1Numeric":
            value = abs(num) * 100
            return ("{:.1f}".format(value)).rstrip("0").rstrip(".")
        if declared_type in {"modInt", "int"}:
            return str(round(abs(num)) if declared_type == "modInt" else round(num))
        return format(num, "g")

    def _binary_numeric(self, target: str, op1: str, op2: str, env: ScriptEnvironment, fn) -> bool:
        v1 = env.resolve_value(op1).as_double()
        v2 = env.resolve_value(op2).as_double()
        env.set(target, fn(v1, v2))
        return True

    def _unary_numeric(self, target: str, operand: str, env: ScriptEnvironment, fn) -> bool:
        env.set(target, fn(env.resolve_value(operand).as_double()))
        return True

    def _execute_arithmetic(self, op: str, args: list[str], env: ScriptEnvironment) -> bool:
        def a(index: int) -> str:
            return args[index] if index < len(args) else ""
        if op in {"Add", "Plus"}:
            return self._binary_numeric(a(0), a(1), a(2), env, lambda x, y: x + y)
        if op == "Sub":
            return self._binary_numeric(a(0), a(1), a(2), env, lambda x, y: x - y)
        if op in {"Mul", "Multiply"}:
            return self._binary_numeric(a(0), a(1), a(2), env, lambda x, y: x * y)
        if op == "Div":
            denominator = env.resolve_value(a(2)).as_double()
            env.set(a(0), 0.0 if denominator == 0.0 else env.resolve_value(a(1)).as_double() / denominator)
            return True
        if op == "Min":
            return self._binary_numeric(a(0), a(1), a(2), env, min)
        if op == "Max":
            return self._binary_numeric(a(0), a(1), a(2), env, max)
        if op == "Avg":
            return self._binary_numeric(a(0), a(1), a(2), env, lambda x, y: (x + y) / 2.0)
        if op == "Floor":
            return self._unary_numeric(a(0), a(1), env, math.floor)
        if op == "Round":
            return self._unary_numeric(a(0), a(1), env, round)
        if op == "Ceil":
            return self._unary_numeric(a(0), a(1), env, math.ceil)
        return False

    def _execute_unit(self, op: str, args: list[str], ctx: ResolutionContext, env: ScriptEnvironment) -> bool:
        def a(index: int) -> str:
            return args[index] if index < len(args) else ""
        if op == "CurrentUnitConfig":
            unit = self.db.get_unit(ctx.unit_id or "")
            if unit is None:
                return False
            try:
                value = json_path_get(unit, a(1))
            except KeyError:
                if self.settings.assume_zero_for_missing_numeric_config and self._looks_numeric_config(a(1)):
                    env.set(a(0), 0.0)
                    return True
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op == "CurrentUnitStats":
            unit = self.db.get_unit(ctx.unit_id or "")
            if unit is None:
                return False
            for candidate in (f"stats.{a(1)}", a(1)):
                try:
                    value = json_path_get(unit, candidate)
                    env.set(a(0), json_as_string(value) or to_number(value))
                    return True
                except KeyError:
                    continue
            if self.settings.assume_zero_for_missing_numeric_config:
                env.set(a(0), 0.0)
                return True
            return False
        if op == "CurrentUnitData":
            unit = self.db.get_unit(ctx.unit_id or "")
            if unit is None:
                return False
            try:
                value = json_path_get(unit, a(1))
            except KeyError:
                if self.settings.assume_baseline_stacks_when_missing and a(1) in {"fullStacks", "startBattleFullStacks"}:
                    env.set(a(0), 0.0)
                    return True
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op == "CurrentAbility":
            unit = self.db.get_unit(ctx.unit_id or "")
            if unit is None:
                return False
            path = a(1)
            try:
                if path.startswith("defaultAttacks"):
                    ability = unwrap_value(json_path_get(unit, path))
                else:
                    arr_name = "abilities" if (ctx.is_active_ability or path.startswith("selfMechanics")) else "passives"
                    arr = unit.get(arr_name)
                    if not isinstance(arr, list):
                        return False
                    idx = ctx.ability_index or 0
                    if idx >= len(arr):
                        return False
                    ability = unwrap_value(json_path_get(arr[idx], path))
            except KeyError:
                if path.endswith(".statDmgMult"):
                    env.set(a(0), 1.0)
                    return True
                if self.settings.assume_zero_for_missing_numeric_config and self._looks_numeric_config(path):
                    env.set(a(0), 1.0 if path.endswith(".statDmgMult") else 0.0)
                    return True
                return False
            env.set(a(0), json_as_string(ability) or to_number(ability))
            return True
        return False

    def _execute_buff(self, op: str, args: list[str], ctx: ResolutionContext, env: ScriptEnvironment) -> bool:
        def a(index: int) -> str:
            return args[index] if index < len(args) else ""
        if op == "CurrentBuff":
            buff = self.db.get_buff(ctx.buff_id or "")
            if buff is None:
                return False
            if a(1).lower() == "charges":
                env.set(a(0), ctx.buff_stacks or 1)
                return True
            actual = self._strip_config_prefix(a(1))
            try:
                value = json_path_get(buff, actual)
            except KeyError:
                if "data.stats.hpPerc" in actual:
                    try:
                        value = json_path_get(buff, actual.replace("data.stats.hpPerc", "data.stats.hp"))
                    except KeyError:
                        if self.settings.assume_zero_for_missing_numeric_config and self._looks_buff_numeric_config(actual):
                            env.set(a(0), 0.0)
                            return True
                        return False
                elif self.settings.assume_zero_for_missing_numeric_config and self._looks_buff_numeric_config(actual):
                    env.set(a(0), 0.0)
                    return True
                else:
                    return False
            value = unwrap_value(value)
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op == "CurrentBuffSP":
            if ctx.buff_spell_power is None:
                return False
            env.set(a(0), ctx.buff_spell_power)
            return True
        if op == "CurrentBuffStacks":
            if ctx.buff_stacks is None:
                return False
            env.set(a(0), ctx.buff_stacks)
            return True
        if op in {"CurrentBuffSumMinDmg", "CurrentBuffSumMaxDmg"}:
            buff = self.db.get_buff(ctx.buff_id or "")
            if buff is None or ctx.buff_stacks is None:
                return False
            stack_path = "actions[0].damageDealer.maxStackDmg" if op.endswith("MaxDmg") else "actions[0].damageDealer.minStackDmg"
            base_path = "actions[0].damageDealer.maxBaseDmg" if op.endswith("MaxDmg") else "actions[0].damageDealer.minBaseDmg"
            try:
                damage = to_number(unwrap_value(json_path_get(buff, stack_path)))
            except KeyError:
                try:
                    damage = to_number(unwrap_value(json_path_get(buff, base_path)))
                except KeyError:
                    return False
            env.set(a(0), damage * ctx.buff_stacks)
            return True
        if op == "DbBuff":
            buff_id = str(env.resolve_value(a(1)))
            buff = self.db.get_buff(buff_id)
            if buff is None:
                return False
            try:
                value = unwrap_value(json_path_get(buff, a(2)))
            except KeyError:
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op == "DbSideBuff":
            buff_id = str(env.resolve_value(a(1)))
            buff = self.db.get_side_buff(buff_id)
            if buff is None:
                return False
            try:
                value = unwrap_value(json_path_get(buff, a(2)))
            except KeyError:
                sid = buff.get("sid") if isinstance(buff, dict) else None
                if not isinstance(sid, str) or not sid:
                    return False
                linked_buff = self.db.get_buff(sid)
                if linked_buff is None:
                    return False
                try:
                    value = unwrap_value(json_path_get(linked_buff, a(2)))
                except KeyError:
                    return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        return False

    def _execute_item(self, op: str, args: list[str], ctx: ResolutionContext, env: ScriptEnvironment) -> bool:
        def a(index: int) -> str:
            return args[index] if index < len(args) else ""
        if op == "CurrentItem":
            item = self.db.get_item(ctx.item_id or "")
            if item is None:
                return False
            if a(1).lower() == "level":
                env.set(a(0), ctx.item_level or 1)
                return True
            actual = self._strip_config_prefix(a(1))
            try:
                value = unwrap_value(json_path_get(item, actual))
            except KeyError:
                fallback = self._resolve_item_bonus_value(item, actual)
                if fallback is not None:
                    env.set(a(0), fallback)
                    return True
                if self.settings.assume_zero_for_missing_numeric_config and self._looks_item_numeric_config(actual):
                    env.set(a(0), 0.0)
                    return True
                return False
            if ctx.item_level and isinstance(value, (int, float)):
                try:
                    increment = to_number(unwrap_value(json_path_get(item, actual + "PerLevel")))
                except KeyError:
                    increment = None
                if increment is not None:
                    env.set(a(0), float(value) + increment * (ctx.item_level - 1))
                    return True
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op == "CurrentItemSet":
            item_set = self.db.get_item_set(ctx.item_set_id or "")
            if item_set is None:
                return False
            actual = self._strip_config_prefix(a(1))
            try:
                value = unwrap_value(json_path_get(item_set, actual))
            except KeyError:
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        return False

    @staticmethod
    def _resolve_item_bonus_value(item: dict[str, Any], path: str) -> float | None:
        match = re.fullmatch(r"bonuses\[(\d+)\]\.parameters\[(\d+)\]", path)
        if match:
            bonus_index = int(match.group(1))
            parameter_index = int(match.group(2))
            bonuses = item.get("bonuses")
            if not isinstance(bonuses, list) or bonus_index >= len(bonuses):
                return None
            bonus = bonuses[bonus_index]
            if not isinstance(bonus, dict):
                return None
            parameters = bonus.get("parameters")
            if not isinstance(parameters, list) or parameter_index >= len(parameters):
                return None
            return to_number(parameters[parameter_index])
        match = re.fullmatch(r"bonuses\[(\d+)\]\.upgrade\.increment", path)
        if match:
            bonus_index = int(match.group(1))
            bonuses = item.get("bonuses")
            if not isinstance(bonuses, list) or bonus_index >= len(bonuses):
                return None
            bonus = bonuses[bonus_index]
            if not isinstance(bonus, dict):
                return None
            upgrade = bonus.get("upgrade")
            if not isinstance(upgrade, dict):
                return 0.0
            increment = upgrade.get("increment")
            return to_number(increment)
        return None

    def _execute_magic(self, op: str, args: list[str], ctx: ResolutionContext, env: ScriptEnvironment) -> bool:
        def a(index: int) -> str:
            return args[index] if index < len(args) else ""
        magic = self.db.get_magic(ctx.magic_id or "") if ctx.magic_id else None
        if op == "CurrentMagicLevel":
            env.set(a(0), ctx.magic_level or 1)
            return True
        if op == "SpellpowerForCurrentMagic":
            if ctx.buff_spell_power is None:
                return False
            env.set(a(0), ctx.buff_spell_power)
            return True
        if magic is None:
            return False
        if op == "CurrentMagicBattle":
            if ctx.magic_level and isinstance(magic.get("levels"), list):
                levels = magic["levels"]
                idx = ctx.magic_level - 1
                if 0 <= idx < len(levels):
                    try:
                        value = unwrap_value(json_path_get(levels[idx], a(1)))
                        env.set(a(0), json_as_string(value) or to_number(value))
                        return True
                    except KeyError:
                        pass
            battle_magic = magic.get("battleMagic")
            search_root = battle_magic if isinstance(battle_magic, dict) else magic
            if isinstance(battle_magic, dict):
                dealers = battle_magic.get("magicDealers")
                if isinstance(dealers, list) and dealers:
                    dealer_index = max((ctx.magic_level or 1) - 1, 0)
                    search_root = dealers[min(dealer_index, len(dealers) - 1)]
            try:
                value = unwrap_value(json_path_get(search_root, a(1)))
            except KeyError:
                try:
                    value = unwrap_value(json_path_get(magic, a(1)))
                except KeyError:
                    if "durationPerStack" in a(1) or "PerStack" in a(1):
                        env.set(a(0), 0.0)
                        return True
                    return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op == "CurrentMagicBattleRoot":
            try:
                value = unwrap_value(json_path_get(magic, a(1)))
            except KeyError:
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op == "CurrentMagicWorld":
            world_magic = magic.get("worldMagic")
            if not isinstance(world_magic, dict):
                return False
            level = max((ctx.magic_level or 1) - 1, 0)
            magic_settings = world_magic.get("magicSettings")
            if isinstance(magic_settings, list):
                settings_index = level
                setting_per_levels = world_magic.get("settingPerLevels")
                if isinstance(setting_per_levels, list) and setting_per_levels:
                    clamped = min(level, len(setting_per_levels) - 1)
                    settings_index = int(setting_per_levels[clamped])
                if settings_index < len(magic_settings):
                    try:
                        value = unwrap_value(json_path_get(magic_settings[settings_index], a(1)))
                        env.set(a(0), json_as_string(value) or to_number(value))
                        return True
                    except KeyError:
                        pass
            try:
                value = unwrap_value(json_path_get(world_magic, a(1)))
            except KeyError:
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        return False

    def _execute_skill(self, op: str, args: list[str], ctx: ResolutionContext, env: ScriptEnvironment) -> bool:
        def a(index: int) -> str:
            return args[index] if index < len(args) else ""
        if op == "CurrentSkillLevel":
            if ctx.skill_level is None:
                return False
            env.set(a(0), ctx.skill_level)
            return True
        if op == "CurrentSkillParameter":
            skill = self.db.get_skill(ctx.skill_id or "")
            if skill is None or ctx.skill_level is None:
                return False
            params_per_level = skill.get("parametersPerLevel")
            if not isinstance(params_per_level, list):
                return False
            idx = ctx.skill_level - 1
            if idx < 0 or idx >= len(params_per_level):
                return False
            try:
                value = unwrap_value(json_path_get(params_per_level[idx], a(1)))
            except KeyError:
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op == "CurrentSubSkill":
            sub_skill = self.db.get_sub_skill(ctx.sub_skill_id or "")
            if sub_skill is None:
                return False
            try:
                value = unwrap_value(json_path_get(sub_skill, a(1)))
            except KeyError:
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        return False

    def _execute_hero(self, op: str, args: list[str], ctx: ResolutionContext, env: ScriptEnvironment) -> bool:
        def a(index: int) -> str:
            return args[index] if index < len(args) else ""
        if op == "CurrentHero":
            if a(1).lower() == "level":
                if self.settings.assume_hero_level_when_missing:
                    env.set(a(0), self.settings.hero_level_baseline)
                    return True
                return False
            if a(1).lower() == "herostat.viewradius":
                env.set(a(0), 1.0)
                return True
            return False
        if op == "CurrentHeroSpecializationConfig":
            spec = self.db.get_hero_specialization(ctx.hero_specialization_id or "")
            if spec is None:
                return False
            try:
                value = unwrap_value(json_path_get(spec, a(1)))
            except KeyError:
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op == "CurrentHeroAbility":
            ability = self.db.get_hero_ability(ctx.hero_ability_id or "")
            if ability is None:
                return False
            levels = ability.get("levels")
            if not isinstance(levels, list) or not levels:
                return False
            actual = a(1).replace(".data.", ".")
            try:
                value = unwrap_value(json_path_get(levels[0], actual))
            except KeyError:
                if self.settings.assume_zero_for_missing_numeric_config and self._looks_hero_numeric_config(actual):
                    env.set(a(0), 0.0)
                    return True
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        return False

    def _execute_db(self, op: str, args: list[str], env: ScriptEnvironment) -> bool:
        def a(index: int) -> str:
            return args[index] if index < len(args) else ""
        if op == "DbAbility":
            ability_id = str(env.resolve_value(a(1)))
            level = int(env.resolve_value(a(2)).as_double())
            ability = self.db.get_ability(ability_id)
            if ability is None:
                return False
            levels = ability.get("levels")
            if not isinstance(levels, list) or level < 0 or level >= len(levels):
                return False
            try:
                value = unwrap_value(json_path_get(levels[level], a(3)))
            except KeyError:
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op == "DbObstacle":
            obstacle = self.db.get_obstacle(str(env.resolve_value(a(1))))
            if obstacle is None:
                return False
            try:
                value = unwrap_value(json_path_get(obstacle, a(2)))
            except KeyError:
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op == "DbTrap":
            trap = self.db.get_trap(str(env.resolve_value(a(1))))
            if trap is None:
                return False
            try:
                value = unwrap_value(json_path_get(trap, a(2)))
            except KeyError:
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        return False

    def _execute_misc(self, op: str, args: list[str], ctx: ResolutionContext, env: ScriptEnvironment) -> bool:
        def a(index: int) -> str:
            return args[index] if index < len(args) else ""
        if op == "CurrentFractionLawConfig":
            law = self.db.get_law(ctx.law_id or "")
            if law is None:
                return False
            actual = self._strip_config_prefix(a(1))
            if not actual.lower().startswith("parametersperlevel"):
                level_index = (ctx.law_level or 1) - 1
                actual = f"parametersPerLevel[{level_index}].{actual}"
            try:
                value = unwrap_value(json_path_get(law, actual))
            except KeyError:
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op == "BuildingsCount":
            env.set(a(0), 0.0)
            return True
        if op in {"CurrentSentry", "EventBankCurrentVariant"}:
            map_obj = self.db.get_map_object(ctx.map_object_id or "")
            if map_obj is None:
                return False
            try:
                value = unwrap_value(json_path_get(map_obj, a(1)))
            except KeyError:
                return False
            env.set(a(0), json_as_string(value) or to_number(value))
            return True
        if op in {"Ability", "Hero", "Unit", "Player", "Side"}:
            env.set(a(0), op.lower())
            return True
        if op == "Campage":
            env.set(a(0), 0.0)
            return True
        if op == "EgorInt":
            env.set(a(0), math.floor(env.resolve_value(a(1)).as_double()))
            return True
        return False

    def _execute_control(self, op: str, args: list[str], ctx: ResolutionContext, env: ScriptEnvironment, return_value_holder: dict[str, str | None]) -> bool:
        def a(index: int) -> str:
            return args[index] if index < len(args) else ""
        if op in {"Call", "Invoke"}:
            fn_name = str(env.resolve_value(a(1)))
            value = self.try_evaluate(fn_name, ctx)
            if value is None:
                return False
            try:
                env.set(a(0), float(value))
            except ValueError:
                env.set(a(0), value)
            return True
        if op == "Return":
            value = str(env.resolve_value(a(0)))
            return_value_holder["value"] = value
            env.set("return", value)
            return True
        if op == "Text":
            if len(args) >= 2 and a(0).lower() == "return":
                value = str(env.resolve_value(a(1)))
                return_value_holder["value"] = value
                env.set("return", value)
                return True
            if len(args) >= 2:
                env.set(a(0), str(env.resolve_value(a(1))))
                return True
            return False
        if op == "Concat":
            pieces = [str(env.resolve_value(part)) for part in args[1:]]
            env.set(a(0), "".join(pieces))
            return True
        if op == "Print":
            return True
        return False

    def _execute_pattern(self, op: str, args: list[str], ctx: ResolutionContext, env: ScriptEnvironment) -> bool:
        target = args[0] if args else ""
        if op.lower().startswith("current_unit_indmgmods_"):
            match = re.match(r"current_unit_inDmgMods_(\d+)_param$", op, re.I)
            if not match:
                return False
            unit = self.db.get_unit(ctx.unit_id or "")
            if unit is None:
                return False
            path = f"passives.inDmgMods[{int(match.group(1))}].param"
            try:
                value = unwrap_value(json_path_get(unit, path))
            except KeyError:
                if self.settings.assume_zero_for_missing_numeric_config:
                    env.set(target, 0.0)
                    return True
                return False
            env.set(target, json_as_string(value) or to_number(value))
            return True
        if op.lower().startswith("current_unit_passives_"):
            unit = self.db.get_unit(ctx.unit_id or "")
            if unit is None:
                return False
            path = f"passives.{op[len('current_unit_passives_') :]}"
            try:
                value = unwrap_value(json_path_get(unit, path))
            except KeyError:
                if self.settings.assume_zero_for_missing_numeric_config:
                    env.set(target, 0.0)
                    return True
                return False
            env.set(target, json_as_string(value) or to_number(value))
            return True
        if op.lower().startswith("current_unit_ability_") or op.lower().startswith("current_unit_passive_"):
            is_ability = op.lower().startswith("current_unit_ability_")
            field_name = op[len("current_unit_ability_") :] if is_ability else op[len("current_unit_passive_") :]
            unit = self.db.get_unit(ctx.unit_id or "")
            if unit is None:
                return False
            arr = unit.get("abilities" if is_ability else "passives")
            if not isinstance(arr, list):
                return False
            idx = ctx.ability_index or 0
            if idx >= len(arr):
                return False
            ability = arr[idx]
            special_paths = {
                "baseBuffDuration": "selfMechanics[0].values[0]",
                "buff_duration": "damageDealer.buff.duration",
                "perStackBuffDuration_unitsBonusDuration": "selfMechanics[0].values[1]",
                "perStackBuffDuration_unitsCount": "selfMechanics[0].values[2]",
                "trap_baseBuffDuration": "damageDealer.targetMechanics[0].values[0]",
            }
            path = special_paths.get(field_name)
            if path is None:
                if self.settings.assume_zero_for_missing_numeric_config:
                    env.set(target, 0.0)
                    return True
                return False
            try:
                value = unwrap_value(json_path_get(ability, path))
            except KeyError:
                return False
            env.set(target, json_as_string(value) or to_number(value))
            return True
        if op.lower().startswith("current_buff_"):
            buff = self.db.get_buff(ctx.buff_id or "")
            if buff is None:
                return False
            suffix = op[len("current_buff_") :]
            if suffix.endswith("_param"):
                stat_name = suffix[:-len("_param")]
                try:
                    value = unwrap_value(json_path_get(buff, f"data.stats.{stat_name}"))
                except KeyError:
                    if self.settings.assume_zero_for_missing_numeric_config:
                        env.set(target, 0.0)
                        return True
                    return False
                env.set(target, json_as_string(value) or to_number(value))
                return True
            if suffix == "dot_dmg":
                try:
                    damage = to_number(unwrap_value(json_path_get(buff, "actions[0].damageDealer.minStackDmg")))
                except KeyError:
                    try:
                        damage = to_number(unwrap_value(json_path_get(buff, "actions[0].damageDealer.minBaseDmg")))
                    except KeyError:
                        return False
                if ctx.buff_stacks:
                    damage *= ctx.buff_stacks
                env.set(target, damage)
                return True
        return False

    @staticmethod
    def _strip_config_prefix(path: str) -> str:
        if path.lower().startswith("config."):
            return path[7:]
        if path.lower().startswith("dataconfig."):
            return path[11:]
        return path

    @staticmethod
    def _looks_numeric_config(path: str) -> bool:
        return any(fragment in path for fragment in (
            ".upgrade.",
            "upgrade.increment",
            ".increment",
            "durationPerStack",
            ".values[",
            ".minBaseDmg",
            ".maxBaseDmg",
            ".minStackDmg",
            ".maxStackDmg",
            ".statDmgMult",
            ".damageMultiplerPerHeroLevel",
        ))

    @staticmethod
    def _looks_item_numeric_config(path: str) -> bool:
        return ".upgrade." in path or path.endswith(".increment")

    @staticmethod
    def _looks_buff_numeric_config(path: str) -> bool:
        return ".upgrade." in path or "durationPerStack" in path or path.endswith(".duration") or ".values[" in path

    @staticmethod
    def _looks_hero_numeric_config(path: str) -> bool:
        return path.endswith(".minBaseDmg") or path.endswith(".maxBaseDmg") or ".values[" in path


class PlaceholderResolver:
    def __init__(self, lang: LangIndex, script_index: InfoScriptIndex, interpreter: ScriptInterpreter, db: DbAccessor):
        self.lang = lang
        self.script_index = script_index
        self.interpreter = interpreter
        self.db = db
        self.memo: dict[str, str] = {}

    def resolve(self, sid: str, ctx: ResolutionContext) -> str:
        cacheable = all(
            value is None
            for value in (
                ctx.unit_id,
                ctx.ability_index,
                ctx.is_active_ability,
                ctx.hero_specialization_id,
                ctx.hero_ability_id,
                ctx.skill_id,
                ctx.sub_skill_id,
                ctx.skill_level,
                ctx.buff_id,
                ctx.buff_stacks,
                ctx.buff_spell_power,
                ctx.item_id,
                ctx.item_level,
                ctx.item_set_id,
                ctx.magic_id,
                ctx.magic_level,
                ctx.fraction_id,
                ctx.law_id,
                ctx.law_level,
                ctx.map_object_id,
            )
        )
        if cacheable and sid in self.memo:
            return self.memo[sid]
        text = self.lang.resolve_text(sid)
        if text is None:
            raise ResolutionError(f"Unknown text sid: {sid}")
        indices = [int(match.group(1)) for match in PLACEHOLDER_RE.finditer(text)]
        if not indices:
            if cacheable:
                self.memo[sid] = text
            return text
        args = self.lang.get_args(sid)
        if not args:
            if ctx.buff_id:
                args = self._try_extract_buff_args(ctx.buff_id, sid)
            if not args:
                raise ResolutionError(f"Missing args for sid: {sid}")

        def evaluate(expr: str) -> str:
            if not expr.strip():
                return ""
            trimmed = expr.strip()
            if len(trimmed) >= 2 and trimmed[0] == '"' and trimmed[-1] == '"':
                return trimmed[1:-1]
            try:
                return format(float(trimmed), "g")
            except ValueError:
                pass
            left, sep, alt_sid = expr.partition("|")
            if sep:
                left_value = evaluate(left)
                alt_text = self.lang.resolve_text(alt_sid)
                if not alt_text:
                    raise ResolutionError(f"Unknown alt sid: {alt_sid}")
                alt_indices = [int(match.group(1)) for match in PLACEHOLDER_RE.finditer(alt_text)]
                if not alt_indices:
                    return alt_text
                alt_args = self.lang.get_args(alt_sid)
                values: dict[int, str] = {}
                use_left_for_zero = 0 in alt_indices and len(alt_args) < len(alt_indices)
                if use_left_for_zero:
                    if "%" in alt_text and not left.endswith("_add"):
                        add_value = evaluate(left + "_add")
                        if add_value and not add_value.startswith("<"):
                            left_value = add_value
                    values[0] = left_value
                for index in alt_indices:
                    if index == 0 and use_left_for_zero:
                        continue
                    arg_index = index - 1 if use_left_for_zero else index
                    if arg_index >= len(alt_args):
                        raise ResolutionError(f"Incomplete alt args for sid: {alt_sid}")
                    values[index] = evaluate(alt_args[arg_index])
                return substitute_placeholders(alt_text, values)
            script_value = self.interpreter.try_evaluate(expr, ctx)
            if script_value is not None:
                return script_value
            astral_summon_hp = self._resolve_astral_summon_hp(expr)
            if astral_summon_hp is not None:
                return astral_summon_hp
            constant = self.script_index.get(expr)
            if constant is not None:
                return constant
            return f"<{expr}>"

        values: dict[int, str] = {}
        if len(args) == 1 and len(set(indices)) > 1:
            single = evaluate(args[0])
            if single and not single.startswith("<"):
                for index in set(indices):
                    values[index] = single
        if not values:
            for index in sorted(set(indices)):
                if index >= len(args):
                    raise ResolutionError(f"Missing arg index for sid {sid}[{index}]")
                values[index] = evaluate(args[index])
        result = substitute_placeholders(text, values)
        if cacheable:
            self.memo[sid] = result
        return result

    def resolve_strict(self, sid: str, ctx: ResolutionContext, label: str) -> str:
        text = self.resolve(sid, ctx)
        if ANY_PLACEHOLDER_RE.search(text):
            raise ResolutionError(f"Unresolved placeholder in {label} ({sid}): {text}")
        unresolved_marker = re.search(r"<[^>]+>", MARKUP_TAG_RE.sub("", text))
        if unresolved_marker:
            raise ResolutionError(f"Unresolved function in {label} ({sid}): {text}")
        return text

    def _try_extract_buff_args(self, buff_id: str, sid: str) -> list[str]:
        buff = self.db.get_buff(buff_id)
        if not buff:
            return []
        if "black_dragon" in sid.lower():
            for action in buff.get("actions", []):
                mechanics = (((action.get("damageDealer") or {}).get("targetMechanics")) or [])
                for mech in mechanics:
                    if mech.get("mech") == "revenge_damage":
                        values = mech.get("values") or []
                        if len(values) >= 4:
                            return [str(values[3])]
        if "reality_distortion" in sid.lower():
            for action in buff.get("actions", []):
                mechanics = (((action.get("damageDealer") or {}).get("targetMechanics")) or [])
                for mech in mechanics:
                    if mech.get("mech") == "take_accumulated_damage":
                        values = mech.get("values") or []
                        if values:
                            return [str(round(to_number(values[0]) * 100))]
        return []

    @staticmethod
    def _resolve_astral_summon_hp(expr: str) -> str | None:
        match = re.fullmatch(r"current_bonus_magic_astral_summon_hp_new_(\d+)", expr)
        if not match:
            return None
        base = int(match.group(1)) + 1
        return f"{base} + hero's Spell Power"


def substitute_placeholders(text: str, values: dict[int, str]) -> str:
    result = text
    for index in sorted(values.keys(), reverse=True):
        result = result.replace("{" + str(index) + "}", values[index] or "")
    return PLACEHOLDER_RE.sub(lambda match: match.group(0), result)


class ImageExporter:
    def __init__(self, game_root: Path, output_root: Path):
        self.game_root = game_root
        self.images_root = output_root / "images"
        self.logical_map: dict[str, str] = {}
        self.name_map: dict[str, str] = {}
        self.exported_count = 0

    def export(self) -> None:
        try:
            import UnityPy
        except ImportError as exc:
            raise ExtractionError("UnityPy is required for standalone image extraction. Install it with `pip install UnityPy`.") from exc
        asset_files = sorted(
            path for path in self.game_root.rglob("*")
            if path.is_file() and path.suffix.lower() in {".assets", ".bundle", ".resS".lower(), ".resource", ".unity3d"}
        )
        if not asset_files:
            raise ExtractionError(f"No Unity asset files found under {self.game_root}")
        env = UnityPy.load(*[str(path) for path in asset_files])
        self.images_root.mkdir(parents=True, exist_ok=True)
        for container_path, obj in env.container.items():
            if obj.type.name != "Texture2D":
                continue
            texture = obj.read()
            image = texture.image
            if image is None:
                continue
            logical_key = container_path.replace("\\", "/").strip("/")
            relative_path = Path("raw") / (sanitize_path_component(logical_key) + ".png")
            file_path = self.images_root / relative_path
            file_path.parent.mkdir(parents=True, exist_ok=True)
            image.save(file_path)
            self.exported_count += 1
            self._register_alias(logical_key, relative_path)
            if getattr(texture, "name", None):
                self._register_name_alias(str(texture.name), relative_path)
        if self.exported_count == 0:
            self._export_named_objects(env.objects, "Sprite", "sprite")
            self._export_named_objects(env.objects, "Texture2D", "texture")
        if self.exported_count == 0:
            raise ExtractionError("UnityPy loaded assets but no textures were exported.")

    def _export_named_objects(self, objects: Iterable[Any], type_name: str, folder_name: str) -> None:
        for obj in objects:
            if obj.type.name != type_name:
                continue
            name = self._read_object_name(obj)
            if not name:
                continue
            try:
                parsed = obj.read()
                image = getattr(parsed, "image", None)
            except Exception:
                continue
            if image is None:
                continue
            relative_path = Path("raw") / folder_name / f"{sanitize_path_component(name)}__{obj.path_id}.png"
            file_path = self.images_root / relative_path
            file_path.parent.mkdir(parents=True, exist_ok=True)
            image.save(file_path)
            self.exported_count += 1
            self._register_name_alias(name, relative_path)

    def _read_object_name(self, obj: Any) -> str | None:
        try:
            typetree = obj.read_typetree()
        except Exception:
            typetree = None
        if isinstance(typetree, dict):
            name = typetree.get("m_Name")
            if isinstance(name, str) and name.strip():
                return name.strip()
        try:
            parsed = obj.read()
        except Exception:
            return None
        name = getattr(parsed, "name", None)
        if isinstance(name, str) and name.strip():
            return name.strip()
        return None

    def _register_alias(self, logical_key: str, relative_path: Path) -> None:
        relative = relative_path.as_posix()
        lower = logical_key.lower()
        self.logical_map[lower] = relative
        basename = Path(lower).name
        self.logical_map[basename] = relative
        if basename.endswith(".png"):
            self.logical_map[basename[:-4]] = relative

    def _register_name_alias(self, name: str, relative_path: Path) -> None:
        relative = relative_path.as_posix()
        lowered = name.lower()
        self.name_map.setdefault(lowered, relative)
        if lowered.endswith(".png"):
            self.name_map.setdefault(lowered[:-4], relative)

    def resolve_icon(self, logical_name: str | None) -> str | None:
        if not logical_name:
            return None
        key = logical_name.replace("\\", "/").strip("/").lower()
        candidates = [key]
        if key.endswith(".png"):
            candidates.append(key[:-4])
        else:
            candidates.append(key + ".png")
        basename = Path(key).name
        candidates.extend([basename, basename[:-4] if basename.endswith(".png") else basename + ".png"])
        for candidate in candidates:
            if candidate in self.logical_map:
                return "images/" + self.logical_map[candidate]
            if candidate in self.name_map:
                return "images/" + self.name_map[candidate]
        return None


class SqliteWriter:
    def __init__(self, db_path: Path, locales: list[str]):
        self.db_path = db_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(self.db_path)
        self.conn.execute("PRAGMA foreign_keys = ON")
        schema_path = Path(__file__).with_name("wiki_runtime_schema.sql")
        if not schema_path.exists():
            raise ExtractionError(f"Schema file not found at {schema_path}")
        self.conn.executescript(schema_path.read_text(encoding="utf-8"))

    def close(self) -> None:
        self.conn.close()

    def write_locale(self, categories: dict[str, list[dict[str, Any]]], manifest: dict[str, Any], write_structure: bool) -> None:
        with self.conn:
            self._write_app_metadata(manifest)
            self._write_units(categories["units"])
            self._write_heroes(categories["heroes"])
            self._write_skills(categories["skills"])
            self._write_subclasses(categories["subclasses"])
            self._write_spells(categories["spells"])
            self._write_item_sets(categories["item_sets"])
            self._write_artifacts(categories["artifacts"])
            self._write_map_objects(categories["map_objects"])
            self._write_map_object_reward_variants(categories.get("map_object_reward_variants", []))
            self._write_map_object_resource_rewards(categories.get("map_object_resource_rewards", []))
            self._write_map_object_bank_metadata(categories.get("map_object_bank_metadata", []))
            self._write_map_object_guard_variants(categories.get("map_object_guard_variants", []))
            self._write_map_object_guard_units(categories.get("map_object_guard_units", []))
            self._write_buildings(categories["buildings"])
            self._write_faction_laws(categories["faction_laws"])
            if write_structure:
                self._write_search_text(categories)

    @staticmethod
    def _unit_ability_id(unit_id: str, is_active: bool, index: int) -> str:
        return f"{unit_id}:{'active' if is_active else 'passive'}:{index}"

    @staticmethod
    def _unit_ability_rows(unit: dict[str, Any]) -> list[tuple[str, int, bool, dict[str, Any]]]:
        rows: list[tuple[str, int, bool, dict[str, Any]]] = []
        order = 0
        for index, ability in enumerate(unit.get("abilities") or []):
            if isinstance(ability, dict):
                rows.append((SqliteWriter._unit_ability_id(str(unit.get("id") or ""), True, index), order, True, ability))
                order += 1
        for index, ability in enumerate(unit.get("passives") or []):
            if isinstance(ability, dict):
                rows.append((SqliteWriter._unit_ability_id(str(unit.get("id") or ""), False, index), order, False, ability))
                order += 1
        return rows

    @staticmethod
    def _map_object_category(source_file: str) -> str | None:
        lower = source_file.lower()
        if lower.endswith("3_resources.json"):
            return "resources"
        if lower.endswith("4_interactables.json"):
            return "interactables"
        if lower.endswith("6_artifacts.json"):
            return "artifacts"
        return None

    @staticmethod
    def _prefab_path(record: dict[str, Any]) -> str | None:
        prefs = record.get("prefs") if isinstance(record.get("prefs"), list) else []
        return next((value for value in prefs if isinstance(value, str) and value), None)

    @staticmethod
    def _pick_first(mapping: dict[str, Any], *keys: str) -> Any:
        for key in keys:
            if key in mapping and mapping[key] is not None:
                return mapping[key]
        return None

    @staticmethod
    def _json_list_count(value: Any) -> int:
        return len(value) if isinstance(value, list) else 0

    @staticmethod
    def _first_bonus_type(bonuses: Any) -> str | None:
        if not isinstance(bonuses, list):
            return None
        for bonus in bonuses:
            if isinstance(bonus, dict):
                bonus_type = bonus.get("type")
                if isinstance(bonus_type, str) and bonus_type:
                    return bonus_type
        return None

    @staticmethod
    def _bool_to_int(value: Any) -> int:
        return 1 if bool(value) else 0

    def _write_app_metadata(self, manifest: dict[str, Any]) -> None:
        game_version = manifest.get("game_version")
        if isinstance(game_version, str) and game_version:
            self.conn.execute(
                "INSERT OR REPLACE INTO app_metadata(key, value) VALUES (?, ?)",
                ("game_version", game_version),
            )

    @staticmethod
    def _extract_weekly_growth(units_hire: Any) -> int | None:
        if not isinstance(units_hire, dict):
            return None
        units = units_hire.get("units")
        if not isinstance(units, list):
            return None
        for unit in units:
            if not isinstance(unit, dict):
                continue
            weekly_increment = unit.get("weeklyIncrement")
            if isinstance(weekly_increment, bool):
                continue
            if isinstance(weekly_increment, int):
                return weekly_increment
            if isinstance(weekly_increment, float):
                return int(round(weekly_increment))
        return None

    @staticmethod
    def _list_value_at(values: Any, index: int) -> Any:
        if not isinstance(values, list) or index < 0 or index >= len(values):
            return None
        return values[index]

    def _write_units(self, units: list[dict[str, Any]]) -> None:
        for unit in units:
            raw = unit.get("raw") if isinstance(unit.get("raw"), dict) else {}
            base_class = unit.get("base_class") if isinstance(unit.get("base_class"), dict) else {}
            stats = raw.get("stats") if isinstance(raw.get("stats"), dict) else {}
            self.conn.execute(
                """
                INSERT OR IGNORE INTO units(
                  id, source_file, faction_id, native_biome, tier, squad_value, counter_attacks,
                  exp_bonus, upgrade_sid, icon_path, base_class_icon_path,
                  hp, offence, defence, damage_min, damage_max, initiative, speed,
                  luck, morale, energy_per_cast, energy_per_round, energy_per_take_damage,
                  action_points, num_counters, morale_min, morale_max, luck_min, luck_max,
                  growth, move_type, out_damage_if_level_above, out_level_above_threshold,
                  in_dmg_mods_json, out_dmg_mods_json,
                  unit_cost_json, tags_json, raw_json,
                  name, description, narrative_description, base_class_name, base_class_description
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    unit.get("id"),
                    unit.get("source_file"),
                    sql_scalar(raw.get("fraction")),
                    sql_scalar(raw.get("nativeBiome")),
                    sql_scalar(raw.get("tier")),
                    sql_scalar(raw.get("squadValue")),
                    sql_scalar(raw.get("counterAttacks")),
                    sql_scalar(raw.get("expBonus")),
                    sql_scalar(raw.get("upgradeSid")),
                    unit.get("icon"),
                    base_class.get("icon"),
                    sql_scalar(stats.get("hp")),
                    sql_scalar(stats.get("offence")),
                    sql_scalar(stats.get("defence")),
                    sql_scalar(stats.get("damageMin")),
                    sql_scalar(stats.get("damageMax")),
                    sql_scalar(stats.get("initiative")),
                    sql_scalar(stats.get("speed")),
                    sql_scalar(stats.get("luck")),
                    sql_scalar(stats.get("moral")),
                    sql_scalar(stats.get("energyPerCast")),
                    sql_scalar(stats.get("energyPerRound")),
                    sql_scalar(stats.get("energyPerTakeDamage")),
                    sql_scalar(stats.get("actionPoints")),
                    sql_scalar(stats.get("numCounters")),
                    sql_scalar(stats.get("moralMin")),
                    sql_scalar(stats.get("moralMax")),
                    sql_scalar(stats.get("luckMin")),
                    sql_scalar(stats.get("luckMax")),
                    sql_scalar(unit.get("growth")),
                    sql_scalar(stats.get("moveType")),
                    sql_scalar(stats.get("outDamageIfLevelAbove")),
                    sql_scalar(stats.get("outLevelAboveThreshold")),
                    json_blob(stats.get("inDmgMods")),
                    json_blob(stats.get("outDmgMods")),
                    json_blob(raw.get("unitCost")),
                    json_blob(raw.get("tags")),
                    json_blob(raw),
                    unit.get("name") or str(unit.get("id") or ""),
                    unit.get("description"),
                    unit.get("narrative_description"),
                    base_class.get("name"),
                    base_class.get("description"),
                ),
            )
            for ability_id, sort_order, is_active, ability in self._unit_ability_rows(unit):
                ability_raw = ability.get("raw") if isinstance(ability.get("raw"), dict) else {}
                self.conn.execute(
                    """
                    INSERT OR IGNORE INTO unit_abilities(
                      id, unit_id, sort_order, is_active, rank, cooldown, energy_level,
                      attack_type, ability_type_sid, icon_path, raw_json, name, description
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        ability_id,
                        unit.get("id"),
                        sort_order,
                        1 if is_active else 0,
                        ability_raw.get("rank"),
                        ability_raw.get("cd"),
                        ability_raw.get("energyLevel"),
                        ability_raw.get("attackType_"),
                        ability.get("ability_type_sid"),
                        ability.get("icon"),
                        json_blob(ability_raw),
                        ability.get("name"),
                        ability.get("description"),
                    ),
                )

    def _write_heroes(self, heroes: list[dict[str, Any]]) -> None:
        for hero in heroes:
            raw = hero.get("raw") if isinstance(hero.get("raw"), dict) else {}
            self.conn.execute(
                """
                INSERT OR IGNORE INTO heroes(
                  id, source_file, faction_id, class_type, specialization_id, specialization_name, native_biome,
                  cost_gold, start_level, portrait_path, class_icon_path,
                  specialization_icon_path, start_stats_json, primary_skills_json, raw_json,
                  name, description, motto, specialization_description
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    hero.get("id"),
                    hero.get("source_file"),
                    raw.get("fraction"),
                    raw.get("classType"),
                    raw.get("specialization"),
                    hero.get("specialization_name"),
                    raw.get("nativeBiome"),
                    raw.get("costGold"),
                    raw.get("startLevel"),
                    hero.get("icon"),
                    hero.get("class_icon"),
                    hero.get("specialization_icon"),
                    json_blob(self._pick_first(raw, "startStats", "stats")),
                    json_blob(raw.get("primarySkills")),
                    json_blob(raw),
                    hero.get("name") or str(hero.get("id") or ""),
                    hero.get("description"),
                    hero.get("motto"),
                    hero.get("specialization_description"),
                ),
            )
            for squad_key in ("startSquad", "startSquadAlt"):
                squad = raw.get(squad_key) if isinstance(raw.get(squad_key), list) else []
                variant = "default" if squad_key == "startSquad" else "alt"
                for slot_index, item in enumerate(squad):
                    if not isinstance(item, dict):
                        continue
                    self.conn.execute(
                        """
                        INSERT OR IGNORE INTO hero_start_squads(
                          hero_id, variant, slot_index, unit_id, min_count, max_count
                        ) VALUES (?, ?, ?, ?, ?, ?)
                        """,
                        (
                            hero.get("id"),
                            variant,
                            slot_index,
                            item.get("sid"),
                            item.get("min"),
                            item.get("max"),
                        ),
                    )

    def _write_skills(self, skills: list[dict[str, Any]]) -> None:
        for skill in skills:
            raw = skill.get("raw") if isinstance(skill.get("raw"), dict) else {}
            levels = [level for level in skill.get("levels") or [] if isinstance(level, dict)]
            if not levels:
                levels = [{}]
            max_level = len(levels)
            for level in levels:
                level_number = sql_scalar(level.get("level"))
                if level_number is None:
                    level_number = 0
                level_raw = level.get("raw") if isinstance(level.get("raw"), dict) else {}
                level_bonuses = level_raw.get("bonuses")
                level_subskills = level_raw.get("subSkills")
                self.conn.execute(
                    """
                    INSERT OR IGNORE INTO skills(
                      id, level, source_file, icon_path, is_pseudo, skill_type,
                      max_level, bonus_count, subskill_count, bonuses_json, subskills_json, raw_json,
                      level_icon_path, level_raw_json, name, description, level_name, level_description
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        skill.get("id"),
                        level_number,
                        skill.get("source_file"),
                        skill.get("icon"),
                        1 if raw.get("isPseudoSkill") else 0,
                        raw.get("skillType"),
                        max_level,
                        self._json_list_count(level_bonuses),
                        self._json_list_count(level_subskills),
                        json_blob(level_bonuses),
                        json_blob(level_subskills),
                        json_blob(raw),
                        level.get("icon"),
                        json_blob(level_raw),
                        skill.get("name") or str(skill.get("id") or ""),
                        skill.get("description"),
                        level.get("name"),
                        level.get("description"),
                    ),
                )
                for sort_order, subskill in enumerate(level.get("subskills") or []):
                    if not isinstance(subskill, dict):
                        continue
                    self.conn.execute(
                        """
                        INSERT OR IGNORE INTO subskills(
                          id, skill_id, skill_level, sort_order, icon_path, bonus_type,
                          requirements_json, bonuses_json, raw_json, name, description
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            subskill.get("id"),
                            skill.get("id"),
                            level_number,
                            sort_order,
                            subskill.get("icon"),
                            self._first_bonus_type((subskill.get("raw") or {}).get("bonuses") if isinstance(subskill.get("raw"), dict) else None),
                            json_blob((subskill.get("raw") or {}).get("requirements") if isinstance(subskill.get("raw"), dict) else None),
                            json_blob((subskill.get("raw") or {}).get("bonuses") if isinstance(subskill.get("raw"), dict) else None),
                            json_blob(subskill.get("raw")),
                            subskill.get("name") or str(subskill.get("id") or ""),
                            subskill.get("description"),
                        ),
                    )

    def _write_subclasses(self, subclasses: list[dict[str, Any]]) -> None:
        for subclass in subclasses:
            raw = subclass.get("raw") if isinstance(subclass.get("raw"), dict) else {}
            requirements = self._pick_first(raw, "activationConditions", "requirements", "unlockRequirements")
            bonuses = self._pick_first(raw, "bonuses", "effects", "parametersPerLevel")
            self.conn.execute(
                """
                INSERT OR IGNORE INTO subclasses(
                  id, source_file, faction_id, class_type, icon_path, activation_conditions_json,
                  requirements_json, bonuses_json, bonus_type, bonus_count, raw_json, name, description
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    subclass.get("id"),
                    subclass.get("source_file"),
                    raw.get("faction"),
                    raw.get("classType"),
                    subclass.get("icon"),
                    json_blob(raw.get("activationConditions")),
                    json_blob(requirements),
                    json_blob(bonuses),
                    self._first_bonus_type(bonuses),
                    self._json_list_count(bonuses),
                    json_blob(raw),
                    subclass.get("name") or str(subclass.get("id") or ""),
                    subclass.get("description"),
                ),
            )

    def _write_spells(self, spells: list[dict[str, Any]]) -> None:
        for spell in spells:
            raw = spell.get("raw") if isinstance(spell.get("raw"), dict) else {}
            levels = [level for level in spell.get("levels") or [] if isinstance(level, dict)]
            if not levels:
                levels = [{}]
            for level in levels:
                level_number = sql_scalar(level.get("level"))
                if level_number is None:
                    level_number = 0
                self.conn.execute(
                    """
                    INSERT OR IGNORE INTO spells(
                      id, level, source_file, icon_path, school, spell_type, used_on_map, max_level,
                      rank, magic_type_description, mana_cost, learn_cost_json, upgrade_cost_json, raw_json,
                      level_raw_json, name, level_description
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        spell.get("id"),
                        level_number,
                        spell.get("source_file"),
                        spell.get("icon"),
                        raw.get("school_"),
                        "world" if raw.get("usedOnMap") else "battle",
                        self._bool_to_int(raw.get("usedOnMap")),
                        len(levels),
                        sql_scalar(raw.get("rank")),
                        raw.get("magicTypeDescription"),
                        sql_scalar(self._list_value_at(raw.get("manaCost"), max(int(level_number) - 1, 0))),
                        json_blob(raw.get("learnCost")),
                        json_blob(raw.get("upgradeCost")),
                        json_blob(raw),
                        json_blob(level),
                        spell.get("name") or str(spell.get("id") or ""),
                        level.get("description"),
                    ),
                )

    def _write_artifacts(self, artifacts: list[dict[str, Any]]) -> None:
        for artifact in artifacts:
            raw = artifact.get("raw") if isinstance(artifact.get("raw"), dict) else {}
            levels = [level for level in artifact.get("levels") or [] if isinstance(level, dict)]
            if not levels:
                levels = [{}]
            for level in levels:
                level_number = sql_scalar(level.get("level"))
                if level_number is None:
                    level_number = 0
                self.conn.execute(
                    """
                    INSERT OR IGNORE INTO artifacts(
                      id, level, source_file, slot, rarity, item_set_id, max_level, has_item_set,
                      goods_value, cost_base, cost_per_level, reward_for_destroy, bonus_count, bonus_type, icon_path,
                      set_effects_json, raw_json, bonuses_json, upgrade_bonuses_json, level_raw_json,
                      name, narrative_description, level_description, upgrade_description
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        artifact.get("id"),
                        level_number,
                        artifact.get("source_file"),
                        raw.get("slot_"),
                        raw.get("rarity"),
                        raw.get("itemSet"),
                        raw.get("maxLevel"),
                        self._bool_to_int(raw.get("itemSet")),
                        sql_scalar(raw.get("goodsValue")),
                        sql_scalar(raw.get("costBase")),
                        sql_scalar(raw.get("costPerLevel")),
                        sql_scalar(raw.get("rewardForDestroy")),
                        self._json_list_count(raw.get("bonuses")),
                        self._first_bonus_type(raw.get("bonuses")),
                        artifact.get("icon"),
                        json_blob(self._pick_first(raw, "setEffects", "itemSetEffects", "itemSetBonuses")),
                        json_blob(raw),
                        json_blob(raw.get("bonuses")),
                        None,
                        json_blob(level),
                        artifact.get("name") or str(artifact.get("id") or ""),
                        artifact.get("narrative_description"),
                        level.get("description"),
                        level.get("upgrade_description"),
                    ),
                )

    def _write_item_sets(self, item_sets: list[dict[str, Any]]) -> None:
        for item_set in item_sets:
            items = [item for item in item_set.get("items") or [] if isinstance(item, str) and item]
            bonuses = [bonus for bonus in item_set.get("bonuses") or [] if isinstance(bonus, dict)]
            self.conn.execute(
                """
                INSERT OR IGNORE INTO item_sets(
                  id, source_file, name, description, item_count, bonus_count,
                  items_json, bonuses_json, raw_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    item_set.get("id"),
                    item_set.get("source_file"),
                    item_set.get("name") or str(item_set.get("id") or ""),
                    item_set.get("description"),
                    len(items),
                    len(bonuses),
                    json_blob(items),
                    json_blob(bonuses),
                    json_blob(item_set.get("raw")),
                ),
            )

    def _write_map_objects(self, map_objects: list[dict[str, Any]]) -> None:
        for map_object in map_objects:
            raw = map_object.get("raw") if isinstance(map_object.get("raw"), dict) else {}
            self.conn.execute(
                """
                INSERT OR IGNORE INTO map_objects(
                  id, source_file, category, prefab_path, icon_path, raw_json,
                  name, description, narrative_description
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    map_object.get("id"),
                    map_object.get("source_file"),
                    self._map_object_category(str(map_object.get("source_file") or "")),
                    self._prefab_path(raw),
                    map_object.get("icon"),
                    json_blob(raw),
                    map_object.get("name") or str(map_object.get("id") or ""),
                    map_object.get("description"),
                    map_object.get("narrative_description"),
                ),
            )

    def _write_map_object_reward_variants(self, variants: list[dict[str, Any]]) -> None:
        for variant in variants:
            self.conn.execute(
                """
                INSERT OR REPLACE INTO map_object_reward_variants(
                  map_object_id, variant_index, logic_object_id, roll_chance
                ) VALUES (?, ?, ?, ?)
                """,
                (
                    variant.get("map_object_id"),
                    variant.get("variant_index"),
                    variant.get("logic_object_id"),
                    variant.get("roll_chance"),
                ),
            )

    def _write_map_object_resource_rewards(self, rewards: list[dict[str, Any]]) -> None:
        for reward in rewards:
            self.conn.execute(
                """
                INSERT OR REPLACE INTO map_object_resource_rewards(
                  map_object_id, variant_index, reward_index, resource_key, amount
                ) VALUES (?, ?, ?, ?, ?)
                """,
                (
                    reward.get("map_object_id"),
                    reward.get("variant_index"),
                    reward.get("reward_index"),
                    reward.get("resource_key"),
                    reward.get("amount"),
                ),
            )

    def _write_map_object_bank_metadata(self, rows: list[dict[str, Any]]) -> None:
        for row in rows:
            self.conn.execute(
                """
                INSERT OR REPLACE INTO map_object_bank_metadata(
                  map_object_id, logic_object_id, visit_type, apply_difficulty_modifier
                ) VALUES (?, ?, ?, ?)
                """,
                (
                    row.get("map_object_id"),
                    row.get("logic_object_id"),
                    row.get("visit_type"),
                    self._bool_to_int(row.get("apply_difficulty_modifier")),
                ),
            )

    def _write_map_object_guard_variants(self, rows: list[dict[str, Any]]) -> None:
        for row in rows:
            self.conn.execute(
                """
                INSERT OR REPLACE INTO map_object_guard_variants(
                  map_object_id, variant_index, roll_chance
                ) VALUES (?, ?, ?)
                """,
                (
                    row.get("map_object_id"),
                    row.get("variant_index"),
                    row.get("roll_chance"),
                ),
            )

    def _write_map_object_guard_units(self, rows: list[dict[str, Any]]) -> None:
        for row in rows:
            self.conn.execute(
                """
                INSERT OR REPLACE INTO map_object_guard_units(
                  map_object_id, variant_index, guard_index, unit_id, amount
                ) VALUES (?, ?, ?, ?, ?)
                """,
                (
                    row.get("map_object_id"),
                    row.get("variant_index"),
                    row.get("guard_index"),
                    row.get("unit_id"),
                    row.get("amount"),
                ),
            )

    def _write_buildings(self, buildings: list[dict[str, Any]]) -> None:
        for building in buildings:
            raw = building.get("raw") if isinstance(building.get("raw"), dict) else {}
            units_hire = raw.get("unitsHire")
            weekly_growth = self._extract_weekly_growth(units_hire)
            levels = [level for level in building.get("levels") or [] if isinstance(level, dict)]
            if not levels:
                levels = [{}]
            for level in levels:
                level_number = sql_scalar(level.get("level"))
                if level_number is None:
                    level_number = 0
                level_raw = level.get("raw") if isinstance(level.get("raw"), dict) else {}
                node_pos = level_raw.get("nodePos") if isinstance(level_raw.get("nodePos"), dict) else {}
                self.conn.execute(
                    """
                    INSERT OR IGNORE INTO buildings(
                      id, level, source_file, faction_id, group_name, scene_slot, is_constructed_on_start,
                      level_on_start, icon_path, raw_json, cost_json, requirements_json, prev_buildings_json,
                      node_x, node_y, units_hire_json, weekly_growth, level_raw_json, name, description
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        building.get("id"),
                        level_number,
                        building.get("source_file"),
                        building.get("faction_id"),
                        building.get("group"),
                        raw.get("sceneSlot"),
                        self._bool_to_int(raw.get("isConstructedOnStart")),
                        sql_scalar(raw.get("levelOnStart")),
                        building.get("icon"),
                        json_blob(raw),
                        json_blob(level.get("costs")),
                        json_blob(level.get("requirements")),
                        json_blob(level_raw.get("prevBuildings")),
                        sql_scalar(node_pos.get("xPos")),
                        sql_scalar(node_pos.get("yPos")),
                        json_blob(units_hire),
                        weekly_growth,
                        json_blob(level_raw),
                        level.get("name"),
                        level.get("description"),
                    ),
                )

    def _write_faction_laws(self, faction_laws: list[dict[str, Any]]) -> None:
        for faction_law in faction_laws:
            raw = faction_law.get("raw") if isinstance(faction_law.get("raw"), dict) else {}
            parameters = raw.get("parametersPerLevel") if isinstance(raw.get("parametersPerLevel"), list) else []
            levels = [level for level in faction_law.get("levels") or [] if isinstance(level, dict)]
            if not levels:
                levels = [{}]
            max_level = len(levels)
            for level in levels:
                level_number = int(level.get("level") or 0)
                params = parameters[level_number - 1] if 0 < level_number <= len(parameters) and isinstance(parameters[level_number - 1], dict) else {}
                bonuses = params.get("bonuses")
                self.conn.execute(
                    """
                    INSERT OR IGNORE INTO faction_laws(
                      id, level, source_file, faction_id, max_level, cost, bonus_count, icon_path, raw_json,
                      parameters_json, bonuses_json, level_raw_json, name, level_description
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        faction_law.get("id"),
                        level_number,
                        faction_law.get("source_file"),
                        str(faction_law.get("id") or "").split("_")[2] if len(str(faction_law.get("id") or "").split("_")) >= 3 else None,
                        max_level,
                        sql_scalar(params.get("cost")),
                        self._json_list_count(bonuses),
                        faction_law.get("icon"),
                        json_blob(raw),
                        json_blob(params),
                        json_blob(params.get("bonuses")),
                        json_blob(params),
                        faction_law.get("name") or str(faction_law.get("id") or ""),
                        level.get("description"),
                    ),
                )

    def _write_search_text(self, categories: dict[str, list[dict[str, Any]]]) -> None:
        rows: list[tuple[str, str, str | None, str | None]] = []
        for unit in categories["units"]:
            rows.append(("units", str(unit.get("id") or ""), unit.get("name"), self._join_text(unit.get("description"), unit.get("narrative_description"))))
            for ability_id, _, _, ability in self._unit_ability_rows(unit):
                rows.append(("abilities", ability_id, ability.get("name"), ability.get("description")))
        for hero in categories["heroes"]:
            rows.append(("heroes", str(hero.get("id") or ""), hero.get("name"), self._join_text(hero.get("description"), hero.get("motto"), hero.get("specialization_description"))))
        for skill in categories["skills"]:
            rows.append(("skills", str(skill.get("id") or ""), skill.get("name"), skill.get("description")))
            for level in skill.get("levels") or []:
                if isinstance(level, dict):
                    rows.append(("skill_levels", f"{skill.get('id')}:{level.get('level')}", level.get("name"), level.get("description")))
                    for subskill in level.get("subskills") or []:
                        if isinstance(subskill, dict):
                            rows.append(("subskills", str(subskill.get("id") or ""), subskill.get("name"), subskill.get("description")))
        for subclass in categories["subclasses"]:
            rows.append(("subclasses", str(subclass.get("id") or ""), subclass.get("name"), subclass.get("description")))
        for spell in categories["spells"]:
            rows.append(("spells", str(spell.get("id") or ""), spell.get("name"), self._join_text(*(level.get("description") for level in spell.get("levels") or [] if isinstance(level, dict)))))
        for artifact in categories["artifacts"]:
            rows.append(("artifacts", str(artifact.get("id") or ""), artifact.get("name"), self._join_text(artifact.get("description"), artifact.get("narrative_description"))))
        for map_object in categories["map_objects"]:
            rows.append(("map_objects", str(map_object.get("id") or ""), map_object.get("name"), self._join_text(map_object.get("description"), map_object.get("narrative_description"))))
        for building in categories["buildings"]:
            for level in building.get("levels") or []:
                if isinstance(level, dict):
                    rows.append(("buildings", f"{building.get('id')}:{level.get('level')}", level.get("name"), level.get("description")))
        for faction_law in categories["faction_laws"]:
            rows.append(("faction_laws", str(faction_law.get("id") or ""), faction_law.get("name"), self._join_text(*(level.get("description") for level in faction_law.get("levels") or [] if isinstance(level, dict)))))
        self.conn.executemany(
            "INSERT INTO search_text(entity_type, entity_id, title, body) VALUES (?, ?, ?, ?)",
            rows,
        )

    @staticmethod
    def _join_text(*parts: Any) -> str | None:
        values = [part.strip() for part in parts if isinstance(part, str) and part.strip()]
        if not values:
            return None
        return "\n\n".join(values)


class WikiExtractor:
    def __init__(
        self,
        game_root: Path,
        output_dir: Path,
        locale: str,
        data_dir: Path | None = None,
        clean_output_dir: bool = True,
        fail_on_missing_icon: bool = True,
        fail_on_unresolved_text: bool = True,
    ):
        self.game_root = game_root
        self.streaming_assets_root = detect_streaming_assets_root(game_root)
        self.output_dir = output_dir
        self.data_dir = data_dir or (output_dir / "data")
        self.archive = CoreArchive(self.streaming_assets_root)
        self.lang = LangIndex(self.streaming_assets_root, locale, fallback_to_english=True)
        self.lang.load(self.archive)
        self.db = DbAccessor(self.archive)
        self.registry = ScriptRegistry(self.archive)
        self.info_scripts = InfoScriptIndex(self.archive)
        self.interpreter = ScriptInterpreter(self.registry, self.db, ScriptSettings())
        self.resolver = PlaceholderResolver(self.lang, self.info_scripts, self.interpreter, self.db)
        self.images = ImageExporter(self.game_root, output_dir)
        self.counts: dict[str, int] = {}
        self.clean_output_dir = clean_output_dir
        self.fail_on_missing_icon = fail_on_missing_icon
        self.fail_on_unresolved_text = fail_on_unresolved_text

    def run(self, export_images: bool = True) -> tuple[dict[str, list[dict[str, Any]]], dict[str, Any]]:
        try:
            if export_images:
                self.images.export()
            else:
                self.images.exported_count = sum(1 for _ in self.images.images_root.rglob("*.png"))
            units = self.export_units()
            categories = {
                "units": units,
                "heroes": self.export_heroes(),
                "abilities": self.export_creature_abilities(units),
                "skills": self.export_skills(),
                "spells": self.export_spells(),
                "item_sets": self.export_item_sets(),
                "artifacts": self.export_artifacts(),
                "buildings": self.export_buildings(),
                "map_objects": self.export_map_objects(),
                "faction_laws": self.export_faction_laws(),
                "subclasses": self.export_subclasses(),
            }
            map_object_reward_variants, map_object_resource_rewards, map_object_bank_metadata, map_object_guard_variants, map_object_guard_units = self.export_map_object_resource_reward_rows(categories["map_objects"])
            categories["map_object_reward_variants"] = map_object_reward_variants
            categories["map_object_resource_rewards"] = map_object_resource_rewards
            categories["map_object_bank_metadata"] = map_object_bank_metadata
            categories["map_object_guard_variants"] = map_object_guard_variants
            categories["map_object_guard_units"] = map_object_guard_units
            for category, payload in categories.items():
                self.counts[category] = len(payload)
            manifest = {
                "game_root": str(self.game_root),
                "streaming_assets_root": str(self.streaming_assets_root),
                "game_version": detect_game_version(self.game_root),
                "locale": self.lang.locale,
                "counts": self.counts,
                "images_exported": self.images.exported_count,
            }
            return categories, manifest
        finally:
            self.archive.close()

    def strict_text(self, sid: str | None, ctx: ResolutionContext, label: str) -> str | None:
        if not sid:
            return None
        try:
            if self.fail_on_unresolved_text:
                return self.resolver.resolve_strict(sid, ctx, label)
            return self.resolver.resolve(sid, ctx)
        except ResolutionError:
            if self.fail_on_unresolved_text:
                raise
            return self.lang.resolve_text(sid)

    def resolve_name(self, sid: str | None, fallback: str) -> str:
        if sid:
            text = self.lang.resolve_text(sid)
            if text:
                return text
        return fallback

    def resolve_map_object_text(self, map_object_id: str, primary_sid: str | None, suffix: str) -> str | None:
        candidates: list[str] = []
        if primary_sid:
            candidates.append(primary_sid)
        candidates.extend([
            f"{map_object_id}_{suffix}",
            f"mapobject.{map_object_id}.{suffix}",
            f"object.{map_object_id}.{suffix}",
        ])
        seen: set[str] = set()
        for sid in candidates:
            if not sid or sid in seen:
                continue
            seen.add(sid)
            text = self.lang.resolve_text(sid)
            if text:
                return text
        return None

    def strict_map_object_text(self, map_object_id: str, primary_sid: str | None, suffix: str, ctx: ResolutionContext, label: str) -> str | None:
        candidates: list[str] = []
        if primary_sid:
            candidates.append(primary_sid)
        candidates.extend([
            f"{map_object_id}_{suffix}",
            f"mapobject.{map_object_id}.{suffix}",
            f"object.{map_object_id}.{suffix}",
        ])
        seen: set[str] = set()
        for sid in candidates:
            if not sid or sid in seen:
                continue
            seen.add(sid)
            if self.lang.resolve_text(sid) is None:
                continue
            text = self.strict_text(sid, ctx, label)
            if text:
                return text
        return None

    def require_icon(self, icon_key: str | None, label: str) -> str | None:
        if not icon_key:
            return None
        resolved = self.images.resolve_icon(icon_key)
        if resolved is None and self.fail_on_missing_icon:
            raise ExtractionError(f"Missing icon for {label}: {icon_key}")
        return resolved

    @staticmethod
    def _strip_file_suffix(name: str, suffix: str) -> str:
        return name[:-len(suffix)] if name.endswith(suffix) else name

    @staticmethod
    def _build_logic_candidates(view_key: str) -> list[str]:
        candidates = [view_key]
        if view_key.endswith("_upg_alt"):
            candidates.append(view_key[:-4])
            candidates.append(view_key[:-8])
        elif view_key.endswith("_upg"):
            candidates.append(view_key[:-4])
        elif view_key.endswith("_alt"):
            candidates.append(view_key[:-4])
        return candidates

    @staticmethod
    def _first_record_element(value: Any) -> dict[str, Any] | None:
        if isinstance(value, dict):
            return value
        if isinstance(value, list):
            for item in value:
                if isinstance(item, dict):
                    return item
        return None

    def _serialize_merged_unit_ability(
        self,
        unit_id: str,
        view_ability: dict[str, Any] | None,
        logic_ability: dict[str, Any] | None,
        ctx: ResolutionContext,
        active: bool,
    ) -> dict[str, Any] | None:
        source = view_ability or logic_ability
        if source is None:
            return None
        icon_key = None
        if isinstance(view_ability, dict):
            icon_key = view_ability.get("icon") or view_ability.get("name")
        if not icon_key and isinstance(logic_ability, dict):
            icon_key = logic_ability.get("icon") or logic_ability.get("name")
        label_source = source.get("name") or source.get("id") or "unknown"
        label = f"unit ability {unit_id}:{label_source}"
        return {
            "name_sid": view_ability.get("name") if isinstance(view_ability, dict) else logic_ability.get("name") if isinstance(logic_ability, dict) else None,
            "description_sid": view_ability.get("description") if isinstance(view_ability, dict) else logic_ability.get("description") if isinstance(logic_ability, dict) else None,
            "icon": self.require_icon(icon_key, label),
            "ability_type_sid": view_ability.get("abilityType") if isinstance(view_ability, dict) else logic_ability.get("abilityType") if isinstance(logic_ability, dict) else None,
            "name": self.resolve_name(view_ability.get("name"), str(view_ability.get("name") or "")) if isinstance(view_ability, dict) and view_ability.get("name") else self.resolve_name(logic_ability.get("name"), str(logic_ability.get("name") or "")) if isinstance(logic_ability, dict) and logic_ability.get("name") else None,
            "description": self.strict_text(view_ability.get("description"), ctx, label) if isinstance(view_ability, dict) and view_ability.get("description") else self.strict_text(logic_ability.get("description"), ctx, label) if isinstance(logic_ability, dict) and logic_ability.get("description") else None,
            "raw": logic_ability if isinstance(logic_ability, dict) else view_ability,
            "is_active": active,
        }

    def _merged_unit_abilities(
        self,
        unit_id: str,
        ctx: ResolutionContext,
        view_unit: dict[str, Any],
        logic_unit: dict[str, Any],
        key: str,
        active: bool,
    ) -> list[dict[str, Any]]:
        view_entries = view_unit.get(key) if isinstance(view_unit.get(key), list) else []
        logic_entries = logic_unit.get(key) if isinstance(logic_unit.get(key), list) else []
        abilities: list[dict[str, Any]] = []
        for index in range(max(len(view_entries), len(logic_entries))):
            view_ability = view_entries[index] if index < len(view_entries) and isinstance(view_entries[index], dict) else None
            logic_ability = logic_entries[index] if index < len(logic_entries) and isinstance(logic_entries[index], dict) else None
            ability_ctx = replace(ctx, ability_index=index, is_active_ability=active)
            merged = self._serialize_merged_unit_ability(unit_id, view_ability, logic_ability, ability_ctx, active)
            if merged is not None:
                abilities.append(merged)
        return abilities

    def export_units(self) -> list[dict[str, Any]]:
        units: list[dict[str, Any]] = []
        logic_records_by_key: dict[str, dict[str, Any]] = {}
        for source_file, records in self.archive.array_entries("DB/units/units_logics/"):
            key = self._strip_file_suffix(Path(source_file).stem, "_l")
            if records:
                logic_records_by_key[key] = records[0]

        for source_file, records in self.archive.array_entries("DB/units/units_views/"):
            key = self._strip_file_suffix(Path(source_file).stem, "_v")
            if not records:
                continue
            record = records[0]
            unit_id = str(record.get("id") or "")
            if record.get("name_") is not None or unit_id == "dragon_upg_alt":
                continue
            logic_record = {}
            for candidate in self._build_logic_candidates(key):
                match = logic_records_by_key.get(candidate)
                if match is not None:
                    logic_record = match
                    break
            if not unit_id:
                continue
            ctx = ResolutionContext(locale=self.lang.locale, unit_id=unit_id)
            icon = self.require_icon(f"icons/units/hex_portraits/{unit_id}", f"unit {unit_id}")
            base_class = None
            base_class_raw = self._first_record_element(record.get("baseClass"))
            if isinstance(base_class_raw, dict):
                base_class = {
                    "name_sid": base_class_raw.get("name"),
                    "description_sid": base_class_raw.get("description"),
                    "icon": self.require_icon(base_class_raw.get("icon") or base_class_raw.get("name"), f"unit base class {unit_id}"),
                    "name": self.resolve_name(base_class_raw.get("name"), str(base_class_raw.get("name") or "")),
                    "description": self.strict_text(base_class_raw.get("description"), ctx, f"unit base class {unit_id}"),
                }
            abilities = self._merged_unit_abilities(unit_id, ctx, record, logic_record, "abilities", True)
            abilities.extend(self._merged_unit_abilities(unit_id, ctx, record, logic_record, "alternativeAttacks", True))
            passives = self._merged_unit_abilities(unit_id, ctx, record, logic_record, "passives", False)
            units.append({
                "id": unit_id,
                "source_file": source_file,
                "name_sid": f"{unit_id}_name",
                "description_sid": f"{unit_id}_description",
                "narrative_description_sid": f"{unit_id}_narrativeDescription",
                "name": self.resolve_name(f"{unit_id}_name", unit_id),
                "description": self.strict_text(f"{unit_id}_description", ctx, f"unit {unit_id} description") if self.lang.resolve_text(f"{unit_id}_description") else None,
                "narrative_description": self.strict_text(f"{unit_id}_narrativeDescription", ctx, f"unit {unit_id} narrative") if self.lang.resolve_text(f"{unit_id}_narrativeDescription") else None,
                "icon": icon,
                "base_class": base_class,
                "abilities": abilities,
                "passives": passives,
                "raw": logic_record or record,
            })
        self._enrich_units_with_growth(units)
        return units

    @staticmethod
    def _base_unit_id(unit_id: str) -> str:
        base_id = unit_id
        if base_id.endswith("_upg_alt"):
            return base_id[:-8]
        if base_id.endswith("_upg"):
            return base_id[:-4]
        if base_id.endswith("_alt"):
            return base_id[:-4]
        return base_id

    def _growth_candidates(self, unit_id: str) -> set[str]:
        candidates: set[str] = set()
        base_id = self._base_unit_id(unit_id)

        def add_variants(core: str) -> None:
            candidates.add(core)
            candidates.add(core + "_upg")
            candidates.add(core + "_upg_alt")
            candidates.add(core + "_alt")

        add_variants(unit_id)
        add_variants(base_id)

        for prefix in ("human_", "humans_", "undead_", "dungeon_", "unfrozen_", "nature_", "demons_", "neutral_"):
            add_variants(prefix + base_id)

        return candidates

    @staticmethod
    def _extract_city_sids(node: dict[str, Any]) -> set[str]:
        results: set[str] = set()
        sids = node.get("sids")
        if not isinstance(sids, list):
            return results
        for item in sids:
            if isinstance(item, str) and item:
                results.add(item)
            elif isinstance(item, dict):
                for key in ("id", "sid"):
                    value = item.get(key)
                    if isinstance(value, str) and value:
                        results.add(value)
        return results

    @staticmethod
    def _city_weekly_increment(node: dict[str, Any]) -> int | None:
        value = node.get("weeklyIncrement")
        if isinstance(value, bool):
            return None
        if isinstance(value, int):
            return value
        if isinstance(value, float):
            return int(round(value))
        return None

    def _collect_city_growth(self, node: Any, candidates: dict[str, str], growth_by_base_id: dict[str, int]) -> None:
        if isinstance(node, dict):
            weekly = self._city_weekly_increment(node)
            if weekly is not None:
                for sid in self._extract_city_sids(node):
                    base_id = candidates.get(sid)
                    if base_id is not None:
                        growth_by_base_id[base_id] = weekly
            for value in node.values():
                self._collect_city_growth(value, candidates, growth_by_base_id)
            return
        if isinstance(node, list):
            for item in node:
                self._collect_city_growth(item, candidates, growth_by_base_id)

    def _enrich_units_with_growth(self, units: list[dict[str, Any]]) -> None:
        candidates: dict[str, str] = {}
        for unit in units:
            unit_id = unit.get("id")
            if not isinstance(unit_id, str) or not unit_id:
                continue
            base_id = self._base_unit_id(unit_id)
            for candidate in self._growth_candidates(unit_id):
                candidates.setdefault(candidate, base_id)

        growth_by_base_id: dict[str, int] = {}
        for _, cities in self.archive.array_entries("DB/objects_logic/cities/"):
            for city in cities:
                self._collect_city_growth(city, candidates, growth_by_base_id)

        for unit in units:
            unit_id = unit.get("id")
            if not isinstance(unit_id, str) or not unit_id:
                continue
            growth = growth_by_base_id.get(self._base_unit_id(unit_id))
            if growth is not None:
                unit["growth"] = growth

    def export_creature_abilities(self, units: list[dict[str, Any]]) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        for unit in units:
            unit_raw = unit.get("raw") if isinstance(unit.get("raw"), dict) else {}
            for ability in unit.get("abilities") or []:
                if not isinstance(ability, dict):
                    continue
                results.append({
                    **ability,
                    "unit_id": unit.get("id"),
                    "unit_name": unit.get("name"),
                    "unit_icon": unit.get("icon"),
                    "unit_tier": unit_raw.get("tier"),
                    "unit_cost": unit_raw.get("unitCost"),
                })
            for ability in unit.get("passives") or []:
                if not isinstance(ability, dict):
                    continue
                results.append({
                    **ability,
                    "unit_id": unit.get("id"),
                    "unit_name": unit.get("name"),
                    "unit_icon": unit.get("icon"),
                    "unit_tier": unit_raw.get("tier"),
                    "unit_cost": unit_raw.get("unitCost"),
                })
        return results

    def _serialize_unit_ability(self, unit_id: str, ability: dict[str, Any], ctx: ResolutionContext, active: bool) -> dict[str, Any]:
        icon_key = ability.get("icon") or ability.get("name")
        label = f"unit ability {unit_id}:{ability.get('name') or ability.get('id') or 'unknown'}"
        return {
            "name_sid": ability.get("name"),
            "description_sid": ability.get("description"),
            "icon": self.require_icon(icon_key, label),
            "ability_type_sid": ability.get("abilityType"),
            "name": self.resolve_name(ability.get("name"), str(ability.get("name") or "")),
            "description": self.strict_text(ability.get("description"), ctx, label),
            "raw": ability,
            "is_active": active,
        }

    def export_heroes(self) -> list[dict[str, Any]]:
        heroes: list[dict[str, Any]] = []
        for source_file, records in self.archive.array_entries("DB/heroes/"):
            for record in records:
                hero_id = str(record.get("id") or "")
                if not hero_id:
                    continue
                name = self.lang.resolve_text(hero_id) or self.lang.resolve_text(f"{hero_id}_name") or hero_id
                spec_id = record.get("specialization")
                ctx = ResolutionContext(locale=self.lang.locale, hero_specialization_id=spec_id if isinstance(spec_id, str) else None)
                specialization = self.db.get_hero_specialization(spec_id) if isinstance(spec_id, str) else None
                icon_key = record.get("icon")
                if isinstance(icon_key, str) and icon_key and not icon_key.endswith("_large"):
                    icon_key = f"{icon_key}_large"
                icon = self.require_icon(icon_key or f"icons/hero_large_portraits/{hero_id}", f"hero {hero_id}")
                heroes.append({
                    "id": hero_id,
                    "source_file": source_file,
                    "name": name,
                    "description": self.strict_text(f"{hero_id}_description", ctx, f"hero {hero_id} description") if self.lang.resolve_text(f"{hero_id}_description") else None,
                    "motto": self.strict_text(f"{hero_id}_motto", ctx, f"hero {hero_id} motto") if self.lang.resolve_text(f"{hero_id}_motto") else None,
                    "specialization_description": self.strict_text(f"{hero_id}_spec_description", ctx, f"hero {hero_id} specialization") if self.lang.resolve_text(f"{hero_id}_spec_description") else None,
                    "specialization_name": self.resolve_name(specialization.get("name") if isinstance(specialization, dict) else None, str(spec_id or "")) if spec_id else None,
                    "icon": icon,
                    "class_icon": self.require_icon(record.get("classIcon") or f"{record.get('classType', '')}_{record.get('fraction', '')}_icon", f"hero class {hero_id}") if record.get("classType") and record.get("fraction") else None,
                    "specialization_icon": self.require_icon(f"icons/hero_specializations/{hero_id}_specialization_icon", f"hero specialization icon {hero_id}"),
                    "raw": record,
                })
        return heroes

    def export_skills(self) -> list[dict[str, Any]]:
        subskills: dict[str, dict[str, Any]] = {}
        for _, records in self.archive.array_entries("DB/heroes_skills/sub_skills/"):
            for record in records:
                sub_id = record.get("id")
                if isinstance(sub_id, str) and sub_id:
                    subskills[sub_id] = record
        results: list[dict[str, Any]] = []
        for source_file, records in self.archive.array_entries("DB/heroes_skills/skills/"):
            for record in records:
                skill_id = str(record.get("id") or "")
                if not skill_id:
                    continue
                level_one_icon_key = None
                parameters_per_level = record.get("parametersPerLevel") or []
                if parameters_per_level and isinstance(parameters_per_level[0], dict):
                    level_one_icon_key = parameters_per_level[0].get("icon")
                levels = []
                for level_index, level_param in enumerate(parameters_per_level, start=1):
                    if not isinstance(level_param, dict):
                        continue
                    ctx = ResolutionContext(locale=self.lang.locale, skill_id=skill_id, skill_level=level_index)
                    resolved_subskills = []
                    for sub_id in level_param.get("subSkills") or []:
                        if not isinstance(sub_id, str):
                            continue
                        sub_record = subskills.get(sub_id, {"id": sub_id})
                        sub_ctx = replace(ctx, sub_skill_id=sub_id)
                        resolved_subskills.append({
                            "id": sub_id,
                            "name": self.resolve_name(sub_record.get("name"), sub_id),
                            "description": self.strict_text(sub_record.get("desc"), sub_ctx, f"subskill {sub_id} description") if sub_record.get("desc") else None,
                            "icon": self.require_icon(sub_record.get("icon"), f"subskill {sub_id}"),
                            "raw": sub_record,
                        })
                    levels.append({
                        "level": level_index,
                        "name": self.resolve_name(level_param.get("name"), f"{skill_id}:{level_index}"),
                        "description": self.strict_text(level_param.get("desc"), ctx, f"skill {skill_id} level {level_index} description") if level_param.get("desc") else None,
                        "icon": self.require_icon(level_param.get("icon"), f"skill {skill_id} level {level_index}"),
                        "subskills": resolved_subskills,
                        "raw": level_param,
                    })
                results.append({
                    "id": skill_id,
                    "source_file": source_file,
                    "name": self.resolve_name(record.get("name"), skill_id),
                    "description": self.strict_text(record.get("desc"), ResolutionContext(locale=self.lang.locale, skill_id=skill_id, skill_level=1), f"skill {skill_id} description") if record.get("desc") else None,
                    "icon": self.require_icon(record.get("icon"), f"skill {skill_id}") or self.require_icon(level_one_icon_key, f"skill {skill_id} level 1"),
                    "levels": levels,
                    "raw": record,
                })
        return results

    def export_spells(self) -> list[dict[str, Any]]:
        spells: list[dict[str, Any]] = []
        for source_file, records in self.archive.array_entries("DB/magics/"):
            for record in records:
                magic_id = str(record.get("id") or "")
                if not magic_id:
                    continue
                levels = []
                descriptions = record.get("description") if isinstance(record.get("description"), list) else []
                for index, sid in enumerate(descriptions, start=1):
                    if not isinstance(sid, str) or not sid:
                        continue
                    ctx = ResolutionContext(locale=self.lang.locale, magic_id=magic_id, magic_level=index)
                    levels.append({
                        "level": index,
                        "description_sid": sid,
                        "description": self.strict_text(sid, ctx, f"spell {magic_id} level {index} description"),
                    })
                spells.append({
                    "id": magic_id,
                    "source_file": source_file,
                    "name": self.resolve_name(record.get("name"), magic_id),
                    "icon": self.require_icon(record.get("icon"), f"spell {magic_id}"),
                    "levels": levels,
                    "raw": record,
                })
        return spells

    def export_item_sets(self) -> list[dict[str, Any]]:
        item_sets: list[dict[str, Any]] = []
        for source_file, records in self.archive.array_entries("DB/items/item_sets/"):
            for record in records:
                item_set_id = str(record.get("id") or "")
                if not item_set_id:
                    continue
                ctx = ResolutionContext(locale=self.lang.locale, item_set_id=item_set_id)
                bonuses = []
                for index, bonus in enumerate(record.get("bonuses") or [], start=1):
                    if not isinstance(bonus, dict):
                        continue
                    bonus_description_sid = bonus.get("desc") if isinstance(bonus.get("desc"), str) else None
                    bonuses.append({
                        "required_items_amount": int(to_number(bonus.get("requiredItemsAmount"))) if bonus.get("requiredItemsAmount") is not None else None,
                        "description": self.strict_text(bonus_description_sid, ctx, f"item set {item_set_id} bonus {index}") if bonus_description_sid else None,
                    })
                item_sets.append({
                    "id": item_set_id,
                    "source_file": source_file,
                    "name": self.resolve_name(record.get("name"), item_set_id),
                    "description": "\n\n".join(
                        bonus.get("description").strip()
                        for bonus in bonuses
                        if isinstance(bonus, dict) and isinstance(bonus.get("description"), str) and bonus.get("description").strip()
                    ) or None,
                    "items": [item for item in record.get("itemsInSet") or [] if isinstance(item, str) and item],
                    "bonuses": bonuses,
                    "raw": record,
                })
        return item_sets

    def export_artifacts(self) -> list[dict[str, Any]]:
        artifacts: list[dict[str, Any]] = []
        for source_file, records in self.archive.array_entries("DB/items/items/"):
            for record in records:
                artifact_id = str(record.get("id") or "")
                if not artifact_id or artifact_id.startswith("campaign_"):
                    continue
                max_level = int(record.get("maxLevel") or 1)
                levels = []
                for level in range(1, max(max_level, 1) + 1):
                    ctx = ResolutionContext(locale=self.lang.locale, item_id=artifact_id, item_level=level, item_set_id=record.get("itemSet") if isinstance(record.get("itemSet"), str) else None)
                    description_sid = record.get("description")
                    levels.append({
                        "level": level,
                        "description": self.strict_text(description_sid, ctx, f"artifact {artifact_id} description level {level}") if description_sid else None,
                        "upgrade_description": self.strict_text(record.get("upgradeDescription"), ctx, f"artifact {artifact_id} upgrade description level {level}") if record.get("upgradeDescription") else None,
                    })
                for level in levels:
                    level_number = int(level.get("level") or 0)
                    upgrade_description = level.get("upgrade_description")
                    level["upgrade_description"] = upgrade_description if level_number < max_level else None
                artifacts.append({
                    "id": artifact_id,
                    "source_file": source_file,
                    "name": self.resolve_name(record.get("name"), artifact_id),
                    "description": levels[0]["description"] if levels else None,
                    "narrative_description": self.strict_text(record.get("narrativeDescription"), ResolutionContext(locale=self.lang.locale, item_id=artifact_id, item_level=1), f"artifact {artifact_id} narrative") if record.get("narrativeDescription") else None,
                    "icon": self.require_icon(record.get("icon"), f"artifact {artifact_id}"),
                    "levels": levels,
                    "raw": record,
                })
        return artifacts

    def export_buildings(self) -> list[dict[str, Any]]:
        buildings: list[dict[str, Any]] = []
        for source_file, records in self.archive.array_entries("DB/objects_logic/cities/"):
            for city in records:
                faction_id = city.get("fraction") if isinstance(city.get("fraction"), str) else None
                for key, value in city.items():
                    if not isinstance(value, list):
                        continue
                    for record in value:
                        if not isinstance(record, dict):
                            continue
                        building_sid = str(record.get("sid") or "")
                        if not building_sid:
                            continue
                        building_id = f"{faction_id}:{building_sid}" if faction_id else building_sid
                        names = record.get("names") if isinstance(record.get("names"), list) else []
                        descriptions = record.get("descriptions") if isinstance(record.get("descriptions"), list) else []
                        parameters = record.get("parametersPerLevel") if isinstance(record.get("parametersPerLevel"), list) else []
                        levels = []
                        max_len = max(len(names), len(descriptions), len(parameters), 1)
                        for level in range(max_len):
                            name_sid = names[level] if level < len(names) and isinstance(names[level], str) else None
                            desc_sid = descriptions[level] if level < len(descriptions) and isinstance(descriptions[level], str) else None
                            raw_level = parameters[level] if level < len(parameters) and isinstance(parameters[level], dict) else {}
                            levels.append({
                                "level": level + 1,
                                "name": self.resolve_name(name_sid, building_sid),
                                "description": self.strict_text(desc_sid, ResolutionContext(locale=self.lang.locale), f"building {building_id} level {level + 1} description") if desc_sid else None,
                                "costs": raw_level.get("costs") if isinstance(raw_level, dict) else None,
                                "requirements": raw_level.get("prevBuildings") if isinstance(raw_level, dict) else None,
                                "raw": raw_level,
                            })
                        icon_names = record.get("icons") if isinstance(record.get("icons"), list) else []
                        buildings.append({
                            "id": building_id,
                            "sid": building_sid,
                            "source_file": source_file,
                            "faction_id": faction_id,
                            "group": key,
                            "levels": levels,
                            "icon": self.require_icon(icon_names[0], f"building {building_id}") if icon_names else None,
                            "raw": record,
                        })
        return buildings

    def export_map_objects(self) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        for source_file, records in self.archive.array_entries("DB/map/objects/"):
            lower = source_file.lower()
            if not lower.endswith("3_resources.json") and not lower.endswith("4_interactables.json") and not lower.endswith("6_artifacts.json"):
                continue
            for record in records:
                map_object_id = str(record.get("id") or "")
                if not map_object_id:
                    continue
                prefs = record.get("prefs") if isinstance(record.get("prefs"), list) else []
                prefab_path = next((value for value in prefs if isinstance(value, str) and value), "")
                ctx = ResolutionContext(locale=self.lang.locale, map_object_id=map_object_id)
                icon = self.require_icon(prefab_path or map_object_id, f"map object {map_object_id}") if prefab_path else None
                name = self.resolve_map_object_text(map_object_id, record.get("name"), "name") or map_object_id
                description = self.strict_map_object_text(map_object_id, record.get("description"), "description", ctx, f"map object {map_object_id} description")
                narrative_description = self.strict_map_object_text(map_object_id, record.get("narrativeDescription"), "narrativeDescription", ctx, f"map object {map_object_id} narrative")
                results.append({
                    "id": map_object_id,
                    "source_file": source_file,
                    "name": name,
                    "description": description,
                    "narrative_description": narrative_description,
                    "icon": icon,
                    "raw": record,
                })
        return results

    @staticmethod
    def _map_object_logic_candidates(map_object: dict[str, Any]) -> list[str]:
        candidates: list[str] = []

        map_object_id = str(map_object.get("id") or "")
        if map_object_id:
            candidates.append(map_object_id)

        raw = map_object.get("raw") if isinstance(map_object.get("raw"), dict) else {}
        prefs = raw.get("prefs") if isinstance(raw.get("prefs"), list) else []
        prefab_path = next((value for value in prefs if isinstance(value, str) and value), "")
        if prefab_path:
            prefab_name = prefab_path.replace("\\", "/").split("/")[-1]
            if prefab_name:
                candidates.append(prefab_name)

        raw_id = str(raw.get("id") or "")
        if raw_id:
            candidates.append(raw_id)

        unique: list[str] = []
        seen: set[str] = set()
        for candidate in candidates:
            if candidate and candidate not in seen:
                unique.append(candidate)
                seen.add(candidate)
        return unique

    @staticmethod
    def _parse_guard_units(raw_value: Any) -> list[dict[str, Any]]:
        guards = raw_value if isinstance(raw_value, list) else []
        rows: list[dict[str, Any]] = []
        for guard_index, guard in enumerate(guards):
            if not isinstance(guard, dict):
                continue
            unit_id = guard.get("sid") if isinstance(guard.get("sid"), str) else None
            amount = guard.get("amount")
            if not unit_id or not isinstance(amount, (int, float, str)):
                continue
            try:
                amount_value = int(float(amount))
            except (TypeError, ValueError):
                continue
            rows.append({
                "guard_index": guard_index,
                "unit_id": unit_id,
                "amount": amount_value,
            })
        return rows

    def export_map_object_resource_reward_rows(self, map_objects: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
        logic_by_id: dict[str, dict[str, Any]] = {}
        logic_ids_by_prefab_name: dict[str, list[str]] = {}

        for entry_name, records in self.archive.array_entries("DB/objects_logic/"):
            relative = entry_name[len("DB/objects_logic/"):]
            if "/" not in relative:
                continue

            source_folder = relative.split("/", 1)[0]
            for record in records:
                logic_id = str(record.get("id") or "")
                if not logic_id:
                    continue
                logic_by_id[logic_id] = {
                    "source_folder": source_folder,
                    "record": deep_copy_json(record),
                }
                logic_ids_by_prefab_name.setdefault(Path(entry_name).stem, []).append(logic_id)

        variant_rows: list[dict[str, Any]] = []
        resource_rows: list[dict[str, Any]] = []
        bank_metadata_rows: list[dict[str, Any]] = []
        guard_variant_rows: list[dict[str, Any]] = []
        guard_unit_rows: list[dict[str, Any]] = []

        for map_object in map_objects:
            map_object_id = str(map_object.get("id") or "")
            if not map_object_id:
                continue

            logic_candidates = self._map_object_logic_candidates(map_object)

            raw = map_object.get("raw") if isinstance(map_object.get("raw"), dict) else {}
            prefs = raw.get("prefs") if isinstance(raw.get("prefs"), list) else []
            prefab_path = next((value for value in prefs if isinstance(value, str) and value), "")
            prefab_name = prefab_path.replace("\\", "/").split("/")[-1] if prefab_path else ""
            if prefab_name:
                sibling_ids = logic_ids_by_prefab_name.get(prefab_name, [])
                ordered_siblings = sorted(sibling_ids, key=lambda value: (value.startswith("custom_"), value))
                for sibling_id in ordered_siblings:
                    if sibling_id not in logic_candidates:
                        logic_candidates.append(sibling_id)

            selected_variant_rows: list[dict[str, Any]] = []
            selected_resource_rows: list[dict[str, Any]] = []
            selected_bank_metadata: dict[str, Any] | None = None
            selected_guard_variant_rows: list[dict[str, Any]] = []
            selected_guard_unit_rows: list[dict[str, Any]] = []

            for candidate in logic_candidates:
                logic_record_wrapper = logic_by_id.get(candidate)
                if logic_record_wrapper is None:
                    continue

                logic_record = logic_record_wrapper["record"]
                logic_object_id = str(logic_record.get("id") or "")
                variants = logic_record.get("variants") if isinstance(logic_record.get("variants"), list) else []
                candidate_variant_rows: list[dict[str, Any]] = []
                candidate_resource_rows: list[dict[str, Any]] = []
                candidate_guard_variant_rows: list[dict[str, Any]] = []
                candidate_guard_unit_rows: list[dict[str, Any]] = []
                candidate_bank_metadata = {
                    "map_object_id": map_object_id,
                    "logic_object_id": logic_object_id or None,
                    "visit_type": sql_scalar(logic_record.get("visitType")),
                    "apply_difficulty_modifier": bool(logic_record.get("applyDifficultyModifier")),
                }

                if not variants:
                    root_guards = self._parse_guard_units(logic_record.get("guardUnits"))
                    if root_guards:
                        candidate_guard_variant_rows.append({
                            "map_object_id": map_object_id,
                            "variant_index": 0,
                            "roll_chance": 100,
                        })
                        candidate_guard_unit_rows.extend({
                            "map_object_id": map_object_id,
                            "variant_index": 0,
                            **guard,
                        } for guard in root_guards)

                for variant_index, variant in enumerate(variants):
                    if not isinstance(variant, dict):
                        continue

                    guard_rows = self._parse_guard_units(variant.get("guardUnits"))
                    if guard_rows:
                        candidate_guard_variant_rows.append({
                            "map_object_id": map_object_id,
                            "variant_index": variant_index,
                            "roll_chance": sql_scalar(variant.get("rollChance")),
                        })
                        candidate_guard_unit_rows.extend({
                            "map_object_id": map_object_id,
                            "variant_index": variant_index,
                            **guard,
                        } for guard in guard_rows)

                    reward_set = variant.get("rewardSet") if isinstance(variant.get("rewardSet"), dict) else {}
                    rewards = reward_set.get("rewards") if isinstance(reward_set.get("rewards"), list) else []

                    variant_resource_rows: list[dict[str, Any]] = []
                    reward_index = 0
                    for reward in rewards:
                        if not isinstance(reward, dict):
                            continue
                        if reward.get("rewardType") != "SideResReward":
                            continue

                        parameters = reward.get("parameters") if isinstance(reward.get("parameters"), list) else []
                        for index in range(0, len(parameters), 2):
                            resource_key = parameters[index] if index < len(parameters) and isinstance(parameters[index], str) else None
                            amount = parameters[index + 1] if index + 1 < len(parameters) else None
                            if not resource_key or not isinstance(amount, (int, float, str)):
                                continue
                            try:
                                amount_value = int(float(amount))
                            except (TypeError, ValueError):
                                continue

                            variant_resource_rows.append({
                                "map_object_id": map_object_id,
                                "variant_index": variant_index,
                                "reward_index": reward_index,
                                "resource_key": resource_key,
                                "amount": amount_value,
                            })
                            reward_index += 1

                    if variant_resource_rows:
                        candidate_variant_rows.append({
                            "map_object_id": map_object_id,
                            "variant_index": variant_index,
                            "logic_object_id": logic_object_id or None,
                            "roll_chance": sql_scalar(variant.get("rollChance")),
                        })
                        candidate_resource_rows.extend(variant_resource_rows)

                if candidate_resource_rows or candidate_guard_unit_rows:
                    selected_variant_rows = candidate_variant_rows
                    selected_resource_rows = candidate_resource_rows
                    selected_bank_metadata = candidate_bank_metadata
                    selected_guard_variant_rows = candidate_guard_variant_rows
                    selected_guard_unit_rows = candidate_guard_unit_rows
                    break

            if not selected_resource_rows and not selected_guard_unit_rows:
                continue

            variant_rows.extend(selected_variant_rows)
            resource_rows.extend(selected_resource_rows)
            if selected_bank_metadata is not None:
                bank_metadata_rows.append(selected_bank_metadata)
            guard_variant_rows.extend(selected_guard_variant_rows)
            guard_unit_rows.extend(selected_guard_unit_rows)

        return variant_rows, resource_rows, bank_metadata_rows, guard_variant_rows, guard_unit_rows

    def export_faction_laws(self) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        for source_file, records in self.archive.array_entries("DB/fractions_laws/"):
            if "fractions_laws_table_" not in source_file:
                continue
            for record in records:
                law_id = str(record.get("id") or "")
                if not law_id:
                    continue
                levels = []
                parameters = record.get("parametersPerLevel") if isinstance(record.get("parametersPerLevel"), list) else []
                for level in range(1, max(len(parameters), 1) + 1):
                    ctx = ResolutionContext(locale=self.lang.locale, law_id=law_id, law_level=level)
                    levels.append({
                        "level": level,
                        "description": self.strict_text(record.get("desc"), ctx, f"faction law {law_id} level {level} description") if record.get("desc") else None,
                    })
                results.append({
                    "id": law_id,
                    "source_file": source_file,
                    "name": self.resolve_name(record.get("name"), law_id),
                    "icon": self.require_icon(record.get("icon"), f"faction law {law_id}"),
                    "levels": levels,
                    "raw": record,
                })
        return results

    def export_subclasses(self) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        for source_file, records in self.archive.array_entries("DB/heroes_sub_classes/"):
            for record in records:
                subclass_id = str(record.get("id") or "")
                if not subclass_id:
                    continue
                results.append({
                    "id": subclass_id,
                    "source_file": source_file,
                    "name": self.resolve_name(record.get("name"), subclass_id),
                    "description": self.strict_text(record.get("desc"), ResolutionContext(locale=self.lang.locale), f"subclass {subclass_id} description") if record.get("desc") else None,
                    "icon": self.require_icon(record.get("icon"), f"subclass {subclass_id}"),
                    "raw": record,
                })
        return results

    def export_abilities(self) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        for source_file, records in self.archive.array_entries("DB/battle_abilities/"):
            for record in records:
                ability_id = str(record.get("id") or "")
                if not ability_id:
                    continue
                results.append({
                    "id": ability_id,
                    "source_file": source_file,
                    "name": self.resolve_name(record.get("name"), ability_id),
                    "description": self.strict_text(record.get("description"), ResolutionContext(locale=self.lang.locale), f"battle ability {ability_id} description") if record.get("description") else None,
                    "icon": self.require_icon(record.get("icon") or record.get("name"), f"battle ability {ability_id}"),
                    "raw": record,
                })
        for source_file, records in self.archive.array_entries("DB/heroes_abilities/"):
            for record in records:
                ability_id = str(record.get("id") or "")
                if not ability_id:
                    continue
                ctx = ResolutionContext(locale=self.lang.locale, hero_ability_id=ability_id)
                results.append({
                    "id": ability_id,
                    "source_file": source_file,
                    "name": self.resolve_name(record.get("name"), ability_id),
                    "description": self.strict_text(record.get("description"), ctx, f"hero ability {ability_id} description") if record.get("description") else None,
                    "icon": self.require_icon(record.get("icon") or record.get("name"), f"hero ability {ability_id}"),
                    "raw": record,
                })
        return results


def detect_streaming_assets_root(game_root: Path) -> Path:
    if (game_root / "Core.zip").exists():
        return game_root
    candidates = list(game_root.glob("*_Data/StreamingAssets"))
    if not candidates:
        candidates = list(game_root.rglob("StreamingAssets"))
    for candidate in candidates:
        if (candidate / "Core.zip").exists():
            return candidate
    raise ExtractionError(f"Could not locate StreamingAssets/Core.zip under {game_root}")


def detect_game_version(game_root: Path) -> str | None:
    search_roots = [game_root]
    if game_root.name == "StreamingAssets":
        search_roots.append(game_root.parent.parent)

    for search_root in search_roots:
        globalgamemanagers_paths = list(search_root.glob("*_Data/globalgamemanagers"))
        globalgamemanagers_paths.append(search_root / "globalgamemanagers")
        for globalgamemanagers_path in globalgamemanagers_paths:
            if not globalgamemanagers_path.exists():
                continue
            text = globalgamemanagers_path.read_bytes().decode("utf-8", errors="ignore")
            for version in GAME_VERSION_RE.findall(text):
                if not version.startswith("6000."):
                    return version
    return None


def list_supported_locales(streaming_assets_root: Path) -> list[str]:
    locales: set[str] = set()
    core_zip_path = streaming_assets_root / "Core.zip"
    with zipfile.ZipFile(core_zip_path) as archive:
        for name in archive.namelist():
            if not name.startswith("Lang/"):
                continue
            parts = name.split("/")
            if len(parts) >= 3 and parts[2] == "texts":
                locales.add(parts[1])
    if not locales:
        raise ExtractionError(f"No locale text folders found in {core_zip_path}")
    return sorted(locales)


def collect_app_image_jobs(db_path: Path) -> dict[str, AppImageJob]:
    jobs: dict[str, AppImageJob] = {}
    queries = [
        "SELECT DISTINCT icon_path FROM units WHERE icon_path IS NOT NULL AND icon_path <> ''",
        "SELECT DISTINCT base_class_icon_path FROM units WHERE base_class_icon_path IS NOT NULL AND base_class_icon_path <> ''",
        "SELECT DISTINCT icon_path FROM unit_abilities WHERE icon_path IS NOT NULL AND icon_path <> ''",
        "SELECT DISTINCT portrait_path FROM heroes WHERE portrait_path IS NOT NULL AND portrait_path <> ''",
        "SELECT DISTINCT class_icon_path FROM heroes WHERE class_icon_path IS NOT NULL AND class_icon_path <> ''",
        "SELECT DISTINCT specialization_icon_path FROM heroes WHERE specialization_icon_path IS NOT NULL AND specialization_icon_path <> ''",
        "SELECT DISTINCT icon_path FROM skills WHERE icon_path IS NOT NULL AND icon_path <> ''",
        "SELECT DISTINCT level_icon_path FROM skills WHERE level_icon_path IS NOT NULL AND level_icon_path <> ''",
        "SELECT DISTINCT icon_path FROM subskills WHERE icon_path IS NOT NULL AND icon_path <> ''",
        "SELECT DISTINCT icon_path FROM subclasses WHERE icon_path IS NOT NULL AND icon_path <> ''",
        "SELECT DISTINCT icon_path FROM spells WHERE icon_path IS NOT NULL AND icon_path <> ''",
        "SELECT DISTINCT icon_path FROM artifacts WHERE icon_path IS NOT NULL AND icon_path <> ''",
        "SELECT DISTINCT icon_path FROM map_objects WHERE icon_path IS NOT NULL AND icon_path <> ''",
        "SELECT DISTINCT icon_path FROM buildings WHERE icon_path IS NOT NULL AND icon_path <> ''",
        "SELECT DISTINCT icon_path FROM faction_laws WHERE icon_path IS NOT NULL AND icon_path <> ''",
    ]
    with sqlite3.connect(db_path) as conn:
        for sql in queries:
            for (relative_path,) in conn.execute(sql):
                if not isinstance(relative_path, str):
                    continue
                normalized = relative_path.replace("\\", "/").strip("/")
                if not normalized or not normalized.startswith("images/"):
                    continue
                jobs[normalized] = AppImageJob(
                    relative_path=normalized,
                    max_dimension=APP_IMAGE_MAX_DIMENSION,
                )
    return jobs


def collect_generated_icon_paths(source_root: Path) -> dict[str, str]:
    icon_paths: dict[str, str] = {}
    images_root = source_root / "images"
    if not images_root.exists():
        return icon_paths
    for key, patterns in KNOWN_ICON_PATTERNS.items():
        for pattern in patterns:
            texture_matches = sorted(images_root.glob(f"raw/texture/{pattern}"))
            if texture_matches:
                icon_paths[key] = texture_matches[0].relative_to(source_root).as_posix()
                break
            sprite_matches = sorted(images_root.glob(f"raw/sprite/{pattern}"))
            if sprite_matches:
                icon_paths[key] = sprite_matches[0].relative_to(source_root).as_posix()
                break
    return icon_paths


def merge_icons_json(source_root: Path, app_root: Path) -> dict[str, str]:
    icons_path = app_root / "icons.json"
    existing: dict[str, str] = {}
    if icons_path.exists():
        try:
            loaded = json.loads(icons_path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                existing = {str(key): str(value) for key, value in loaded.items() if isinstance(value, str)}
        except json.JSONDecodeError:
            existing = {}

    merged = existing.copy()
    merged.update(collect_generated_icon_paths(source_root))
    icons_path.write_text(json.dumps(merged, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    return merged


def should_skip_app_image(source_path: Path, dest_path: Path) -> bool:
    return dest_path.exists() and dest_path.stat().st_mtime >= source_path.stat().st_mtime


def downsample_app_image(source_path: Path, dest_path: Path, max_dimension: int) -> None:
    with Image.open(source_path) as image:
        rendered = image.convert("RGBA") if image.mode not in {"RGBA", "LA"} else image.copy()
        rendered.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        rendered.save(dest_path, format="PNG", optimize=True)


def prepare_app_images(source_root: Path, db_path: Path, dest_root: Path) -> None:
    jobs = collect_app_image_jobs(db_path)
    for relative_path in collect_generated_icon_paths(source_root).values():
        jobs[relative_path] = AppImageJob(
            relative_path=relative_path,
            max_dimension=APP_IMAGE_MAX_DIMENSION,
        )
    for relative_path in sorted(jobs):
        job = jobs[relative_path]
        source_path = source_root / relative_path
        if not source_path.exists():
            continue
        dest_path = dest_root / relative_path.removeprefix("images/")
        if should_skip_app_image(source_path, dest_path):
            continue
        downsample_app_image(source_path, dest_path, job.max_dimension)


def resolve_settings() -> tuple[Path, Path, Path, Path, str, bool, bool, bool, bool]:
    game_path = SETTINGS["game_path"]
    output_dir = SETTINGS["output_dir"]
    app_db_path = SETTINGS["app_db_path"]
    app_images_dir = SETTINGS["app_images_dir"]
    locale = SETTINGS["locale"]
    if not game_path:
        raise ExtractionError("Set SETTINGS['game_path'] at the top of the script before running it.")
    if not output_dir:
        raise ExtractionError("Set SETTINGS['output_dir'] at the top of the script before running it.")
    if not app_db_path:
        raise ExtractionError("Set SETTINGS['app_db_path'] at the top of the script before running it.")
    if not app_images_dir:
        raise ExtractionError("Set SETTINGS['app_images_dir'] at the top of the script before running it.")

    return (
        Path(game_path).expanduser().resolve(),
        Path(output_dir).expanduser().resolve(),
        Path(app_db_path).expanduser().resolve(),
        Path(app_images_dir).expanduser().resolve(),
        locale or "english",
        bool(SETTINGS["clean_output_dir"]),
        bool(SETTINGS["clean_app_images_dir"]),
        bool(SETTINGS["fail_on_missing_icon"]),
        bool(SETTINGS["fail_on_unresolved_text"]),
    )


def main() -> int:
    game_path, output_dir, app_db_path, app_images_dir, locale, clean_output_dir, clean_app_images_dir, fail_on_missing_icon, fail_on_unresolved_text = resolve_settings()
    streaming_assets_root = detect_streaming_assets_root(game_path)
    locales = list_supported_locales(streaming_assets_root) if locale.lower() == "all" else [locale]
    if clean_output_dir and output_dir.exists():
        shutil.rmtree(output_dir)
    if clean_app_images_dir and app_images_dir.exists():
        shutil.rmtree(app_images_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    app_db_path.parent.mkdir(parents=True, exist_ok=True)
    if app_db_path.exists():
        app_db_path.unlink()
    writer = SqliteWriter(app_db_path, locales)
    shared_images = None
    try:
        for index, locale_name in enumerate(locales):
            extractor = WikiExtractor(
                game_path,
                output_dir,
                locale_name,
                clean_output_dir=False,
                fail_on_missing_icon=fail_on_missing_icon,
                fail_on_unresolved_text=fail_on_unresolved_text,
            )
            if shared_images is None:
                shared_images = extractor.images
            else:
                extractor.images = shared_images
            categories, manifest = extractor.run(export_images=index == 0)
            writer.write_locale(categories, manifest, write_structure=index == 0)
        merge_icons_json(output_dir, app_db_path.parent.parent)
    finally:
        writer.close()
    prepare_app_images(output_dir, app_db_path, app_images_dir)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ExtractionError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
