"""Offline curriculum gate. Schema/text checks do not certify linguistic accuracy."""
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from pathlib import Path

from jsonschema import Draft202012Validator

from contracts.validate import ContractError, ROOT, load_json, validate_payload

CONTENT_ROOT = ROOT.parents[1] / 'data'
MODELS = ('vocabulary', 'kanji', 'grammar')
KANJI = re.compile(r'[\u3400-\u4dbf\u4e00-\u9fff\U00020000-\U0003134f]')
KANA = re.compile(r'[\u3040-\u30ff]')


def _text(value):
    """Reject invisible/blank/noncanonical text recursively, including examples."""
    if isinstance(value, str):
        if not value.strip() or value != value.strip():
            raise ContractError('Blank or untrimmed content text')
        if unicodedata.normalize('NFC', value) != value:
            raise ContractError('Content text must use NFC Unicode')
        if any(unicodedata.category(c) in {'Cc', 'Cf', 'Cs'} for c in value):
            raise ContractError('Control/invisible characters are forbidden')
    elif isinstance(value, dict):
        for child in value.values():
            _text(child)
    elif isinstance(value, list):
        for child in value:
            _text(child)


def _key(value):
    return ''.join(unicodedata.normalize('NFKC', value).casefold().split())


def _reading(value):
    normalized = unicodedata.normalize('NFKC', value)
    if not KANA.search(normalized) or KANJI.search(normalized) or re.search(r'[A-Za-z]', normalized):
        raise ContractError('Reading must use kana, without Kanji or romaji')


def _load_export(path):
    """Reject ambiguous duplicate object members instead of silently overwriting."""
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ContractError(f'Duplicate JSON member: {key}')
            result[key] = value
        return result

    def invalid_constant(value):
        raise ContractError(f'Non-finite JSON value: {value}')

    with Path(path).open(encoding='utf-8') as source:
        return json.load(source, object_pairs_hook=unique_object,
                         parse_constant=invalid_constant)


def validate_content(root=CONTENT_ROOT):
    """Validate every declared level bundle, rejecting undeclared JSON exports."""
    root = Path(root)
    manifest = _load_export(root / 'manifest.json')
    manifest_schema = load_json(Path(__file__).with_name('content_manifest.schema.json'))
    errors = list(Draft202012Validator(manifest_schema).iter_errors(manifest))
    if errors:
        raise ContractError(f'Content manifest: {errors[0].message}')
    schema = load_json(ROOT / 'models.schema.json')
    if len(set(manifest['levels'])) != len(manifest['levels']):
        raise ContractError('Duplicate level bundles')
    expected = {Path('manifest.json')}
    identifiers = set()
    total = {model: 0 for model in MODELS}
    total['examples'] = 0
    for level in manifest['levels']:
        rows = {}
        for model in MODELS:
            relative = Path(level.lower()) / f'{model}.json'
            expected.add(relative)
            items = _load_export(root / relative)
            if not isinstance(items, list) or not items:
                raise ContractError(f'{relative}: expected a nonempty array')
            rows[model] = items
            keys = set()
            for item in items:
                validate_payload(model, item, schema)
                _text(item)
                if item['jlpt_level'] != level or item['content_version'] != manifest['content_version']:
                    raise ContractError('Wrong level or content version')
                if item['is_active'] is not True:
                    raise ContractError('Published seed must contain active items')
                # UUID spelling must not hide a cross-model collision.
                uid = item['id'].lower()
                if uid in identifiers:
                    raise ContractError('Duplicate curriculum ID')
                identifiers.add(uid)
                field = {'vocabulary': 'expression', 'kanji': 'character', 'grammar': 'pattern'}[model]
                key = _key(item[field])
                if key in keys:
                    raise ContractError(f'Duplicate {model} natural key')
                keys.add(key)
                if model == 'vocabulary':
                    _reading(item['reading'])
                    if not KANA.search(item['expression']) and not KANJI.search(item['expression']):
                        raise ContractError('Vocabulary expression must be Japanese')
                    if len(set(map(_key, item['tags']))) != len(item['tags']):
                        raise ContractError('Duplicate normalized tags')
                if model == 'kanji':
                    if not KANJI.fullmatch(item['character']):
                        raise ContractError('Kanji character must be a CJK ideograph')
                    for reading in item['onyomi'] + item['kunyomi']:
                        _reading(reading)
                examples = item.get('examples', [])
                example_keys = set()
                for example in examples:
                    if not KANA.search(example['sentence_ja']) and not KANJI.search(example['sentence_ja']):
                        raise ContractError('Example sentence must be Japanese')
                    _reading(example['reading_ja'])
                    key = _key(example['sentence_ja'])
                    if key in example_keys:
                        raise ContractError('Duplicate example within an item')
                    example_keys.add(key)
                total[model] += 1
                total['examples'] += len(examples)
        grammar_ids = {item['id'].lower() for item in rows['grammar']}
        for item in rows['grammar']:
            refs = [uid.lower() for uid in item['related_grammar_ids']]
            if len(set(refs)) != len(refs) or item['id'].lower() in refs:
                raise ContractError('Duplicate or self-related grammar reference')
            if not set(refs) <= grammar_ids:
                raise ContractError('Dangling or wrong-type grammar reference')
        counts = {model: len(rows[model]) for model in MODELS}
        counts['examples'] = sum(len(item.get('examples', [])) for group in rows.values() for item in group)
        if manifest['counts'].get(level) != counts:
            raise ContractError('Coverage counts differ from actual content')
        for model, field, flag in [('vocabulary', 'audio_ref', 'audio_available'), ('kanji', 'stroke_data_ref', 'stroke_assets_available')]:
            available = all(item[field] is not None for item in rows[model])
            if manifest[flag] != available:
                raise ContractError('Asset availability does not match content')
            if not manifest[flag] and any(item[field] is not None for item in rows[model]):
                raise ContractError('Partial assets need a versioned coverage contract')
    if set(manifest['counts']) != set(manifest['levels']):
        raise ContractError('Coverage contains undeclared levels')
    actual = {p.relative_to(root) for p in root.rglob('*.json')}
    if actual != expected:
        raise ContractError(f'Undeclared/missing content JSON: {actual ^ expected}')
    return total


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=CONTENT_ROOT)
    args = parser.parse_args()
    print('Validated content: ' + json.dumps(validate_content(args.root), ensure_ascii=False))
