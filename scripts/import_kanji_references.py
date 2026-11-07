"""Hash-locked KanjiVG N5/N4 subsets -> deterministic CC BY-SA normalized guide.

Only the M/C/S commands actually present in the pinned subset are accepted.
Never infer an unsupported command, reorder strokes or fit a glyph to its bounds.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import xml.etree.ElementTree as ET

SVG = '{http://www.w3.org/2000/svg}'
KVG = '{http://kanjivg.tagaini.net}'
COMMIT = '70a0b7ae0c18ceb5cb358274b029cce0234a43bc'
VERSION = 'kanjivg-70a0b7ae-n5-1'
TOKEN = re.compile(r'[MmCcSs]|[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?')
OUTPUT = Path('apps/flutter_app/assets/kanji_references/n5.json')
# Explicit reviewed coverage; never infer the level/version from input rows.
LEVELS = {
    'n5': (8, VERSION, OUTPUT),
    'n4': (95, 'kanjivg-70a0b7ae-n4-1', Path('apps/flutter_app/assets/kanji_references/n4.json')),
}


def require(value, message):
    if not value:
        raise ValueError(message)


def midpoint(a, b):
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)


def segment_distance(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = dx * dx + dy * dy
    t = 0 if length == 0 else max(0, min(1, ((p[0]-a[0])*dx + (p[1]-a[1])*dy) / length))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)


def flatten(a, b, c, d, depth=0):
    error = max(segment_distance(b, a, d), segment_distance(c, a, d))
    if error <= 0.15:
        return [d]
    require(depth < 12, 'Curve subdivision bound')
    ab, bc, cd = midpoint(a, b), midpoint(b, c), midpoint(c, d)
    abc, bcd = midpoint(ab, bc), midpoint(bc, cd)
    center = midpoint(abc, bcd)
    return flatten(a, ab, abc, center, depth+1) + flatten(center, bcd, cd, d, depth+1)


def normalize_path(source):
    require(isinstance(source, str) and len(source) <= 32000, 'Path size')
    require(not TOKEN.sub('', source).strip(' ,\t\r\n'), 'Unsupported SVG path syntax')
    tokens = TOKEN.findall(source)
    require(tokens and tokens[0] in ('M', 'm'), 'Single initial move required')
    index = 1

    def numbers(count):
        nonlocal index
        require(index + count <= len(tokens), 'Truncated path')
        try:
            result = [float(t) for t in tokens[index:index+count]]
        except ValueError as error:
            raise ValueError('Expected path numbers') from error
        require(all(math.isfinite(x) for x in result), 'Nonfinite path')
        index += count
        return result

    xy = numbers(2)
    current = (xy[0], xy[1])
    points = [current]
    control = None
    command = None
    while index < len(tokens):
        if tokens[index] in ('C', 'c', 'S', 's'):
            command = tokens[index]
            index += 1
        require(command is not None, 'Unsupported implicit command')
        values = numbers(6 if command in ('C', 'c') else 4)
        relative = command.islower()
        pairs = [(values[i], values[i+1]) for i in range(0, len(values), 2)]
        if relative:
            pairs = [(x+current[0], y+current[1]) for x, y in pairs]
        if command in ('S', 's'):
            reflected = current if control is None else (2*current[0]-control[0], 2*current[1]-control[1])
            b, c, d = reflected, pairs[0], pairs[1]
        else:
            b, c, d = pairs
        points.extend(flatten(current, b, c, d))
        require(len(points) <= 4096, 'Point bound')
        current, control = d, c
    require(2 <= len(points) <= 4096, 'Empty stroke')
    require(all(0 <= x <= 109 and 0 <= y <= 109 for x, y in points), 'Outside original canvas')
    result = [[round(x/109, 8), round(y/109, 8)] for x, y in points]
    result = [p for i, p in enumerate(result) if i == 0 or p != result[i-1]]
    require(len(result) >= 2, 'Degenerate stroke')
    return result


def parse_svg(source, character, count):
    require(len(source) <= 256000, 'SVG size')
    root = ET.fromstring(source)
    require(root.tag == SVG+'svg' and root.get('viewBox') == '0 0 109 109', 'Canvas mismatch')
    code = f'{ord(character):05x}'
    group = root.find(f"{SVG}g[@id='kvg:StrokePaths_{code}']")
    require(group is not None, 'Missing stroke group')
    glyph = group.find(f"{SVG}g[@id='kvg:{code}']")
    require(glyph is not None and glyph.get(KVG+'element') == character, 'Glyph identity mismatch')
    require(all('transform' not in node.attrib for node in group.iter()), 'Unsupported stroke transform')
    paths = group.findall('.//'+SVG+'path')
    require(len(paths) == count, 'Stroke count mismatch')
    require([p.get('id') for p in paths] == [f'kvg:{code}-s{i+1}' for i in range(count)], 'Stroke order IDs mismatch')
    return [normalize_path(p.get('d')) for p in paths]


def generate(root, level='n5'):
    require(level in LEVELS, 'Unreviewed reference level')
    coverage, version, _ = LEVELS[level]
    folder = root/'third_party/kanjivg'
    manifest = json.loads((folder/f'{level}_manifest.json').read_text(encoding='utf-8'))
    require(manifest['source_commit'] == COMMIT and manifest['reference_version'] == version, 'Unreviewed source version')
    require(manifest['format_version'] == 1, 'Unknown format version')
    require(manifest['source_url'] == 'https://github.com/KanjiVG/kanjivg', 'Unknown source URL')
    require(manifest['license'] == 'CC-BY-SA-3.0' and manifest['license_url'] == 'https://creativecommons.org/licenses/by-sa/3.0/', 'License metadata mismatch')
    require(hashlib.sha256((folder/'COPYING').read_bytes()).hexdigest() == manifest['license_sha256'], 'License digest mismatch')
    metadata = (root/f'data/{level}/kanji.json').read_bytes()
    require(hashlib.sha256(metadata).hexdigest() == manifest['metadata_sha256'], 'Metadata digest mismatch')
    rows = json.loads(metadata)
    require(len(rows) == len(manifest['sources']) == coverage, 'Coverage mismatch')
    entries = []
    for row, entry in zip(rows, manifest['sources']):
        require(row['id'] == entry['kanji_id'] and row['character'] == entry['character'], 'Original ID mapping mismatch')
        require(row['content_version'] == entry['content_version'] and row['stroke_count'] == entry['stroke_count'], 'Original version/count mismatch')
        require(row['jlpt_level'] == level.upper() and row['is_active'] is True, 'Inactive/foreign metadata')
        require(entry['source_file'] == f"{ord(row['character']):05x}.svg", 'Unsafe source path')
        source = (folder/f'{level}_source'/entry['source_file']).read_bytes()
        require(hashlib.sha256(source).hexdigest() == entry['sha256'], 'Source digest mismatch')
        strokes = parse_svg(source, row['character'], row['stroke_count'])
        entries.append({
            'kanji_id': row['id'], 'character': row['character'], 'content_version': row['content_version'],
            'stroke_count': row['stroke_count'], 'source_file': entry['source_file'], 'source_sha256': entry['sha256'],
            'strokes': strokes,
        })
    result = {k: manifest[k] for k in ('format_version', 'reference_version', 'source_commit', 'source_url', 'author', 'license', 'license_url', 'copyright', 'changes')}
    result['entries'] = entries
    return json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False)+'\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--level', choices=['all', *LEVELS], default='all')
    options = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    for level in LEVELS if options.level == 'all' else [options.level]:
        generated = generate(root, level)
        coverage, _, output = LEVELS[level]
        target = root/output
        if options.check:
            require(target.read_bytes() == generated.encode('utf-8'), 'Generated reference drift')
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(generated, encoding='utf-8', newline='\n')
        print(f'PASS: {coverage} pinned original {level.upper()} mappings, ordered bounded curves and deterministic reference output')



if __name__ == '__main__':
    main()
