"""Generate TypeScript projections; runtime truth remains the frozen schema."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFS = json.loads((ROOT / 'contracts/v0.1/models.schema.json').read_text())['$defs']


def ts(schema):
    if '$ref' in schema:
        return schema['$ref'].split('/')[-1]
    if 'const' in schema:
        return json.dumps(schema['const'])
    if 'enum' in schema:
        return ' | '.join(json.dumps(v) for v in schema['enum'])
    if 'anyOf' in schema:
        return ' | '.join(ts(v) for v in schema['anyOf'])
    kind = schema['type']
    if kind == 'object':
        required = schema.get('required', [])
        return '{ ' + '; '.join('readonly ' + k + ('' if k in required else '?') + ': ' + ts(v)
                               for k, v in schema['properties'].items()) + ' }'
    if kind == 'array':
        return 'ReadonlyArray<' + ts(schema['items']) + '>'
    return {'string': 'string', 'number': 'number', 'integer': 'number', 'boolean': 'boolean', 'null': 'null'}[kind]


if __name__ == '__main__':
    content = '// Generated from contracts/v0.1/models.schema.json; do not edit.\n'
    content += '\n'.join('export type ' + k + ' = ' + ts(v) + ';' for k, v in DEFS.items()) + '\n'
    (ROOT / 'backend/ai/src/wire.ts').write_text(content)
