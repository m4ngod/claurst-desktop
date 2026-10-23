"""Reproduce documented text differences; never execute upstream generators."""
import hashlib
import re


def check_bytes(data, size, checksum, label):
    if len(data) != size or hashlib.sha256(data).hexdigest() != checksum:
        raise SystemExit('LaTeX source transformation differs: ' + label)


def normalize_xcharter(data):
    rows = [line for line in data.decode('utf-8').splitlines()
            if line.strip() and not line.lstrip().startswith(('%', '#', ';', '*'))]
    rows.sort(key=lambda line: line.split()[0])
    normalized = []
    for line in rows:
        line = re.sub(r'\s+', ' ', line).rstrip()
        line = re.sub(r'\s*"\s*', ' " ', line)
        if line not in normalized:
            normalized.append(line)
    return ('% XCharter.map\n' + '\n'.join(normalized) + '\n').encode('utf-8')


def reconstruct(entry, source_bytes):
    """Use verified inputs and an explicit recipe, without reading candidate text."""
    lines = source_bytes[entry['baseline']].splitlines(keepends=True)
    block_steps = {}
    for step in entry['transformations']:
        operation = step['operation']
        if operation == 'replace_line':
            index = step['original_line_1_based'] - 1
            if index < 0 or index >= len(lines) or lines[index] != step['before'].encode():
                raise SystemExit('LaTeX source line differs from the documented baseline.')
            lines[index] = step['after'].encode()
        elif operation in ('remove_map_block', 'replace_map_block'):
            label = step['label']
            if label in block_steps:
                raise SystemExit('Duplicate LaTeX mapping block operation: ' + label)
            block_steps[label] = step
        else:
            raise SystemExit('Unsupported LaTeX source transformation: ' + operation)
    data = b''.join(lines)
    if block_steps:
        blocks = list(re.finditer(rb'^% ([^\r\n]+\.map)\n', data, re.M))
        if not blocks:
            raise SystemExit('LaTeX mapping blocks are absent from the source.')
        output = [data[:blocks[0].start()]]
        for index, match in enumerate(blocks):
            label = match.group(1).decode('ascii')
            block = data[match.start():blocks[index + 1].start() if index + 1 < len(blocks) else len(data)]
            step = block_steps.pop(label, None)
            if step is None:
                output.append(block)
                continue
            check_bytes(block, step['original_size'], step['original_sha256'], label)
            if (data[:match.start()].count(b'\n') + 1 != step['original_start_line_1_based']
                    or block.count(b'\n') != step['original_line_count']):
                raise SystemExit('LaTeX mapping block position differs: ' + label)
            if step['operation'] == 'replace_map_block':
                if label != 'XCharter.map':
                    raise SystemExit('Unsupported LaTeX mapping replacement: ' + label)
                replacement = normalize_xcharter(source_bytes[step['source_path']])
                check_bytes(replacement, step['replacement_size'], step['replacement_sha256'], label)
                output.append(replacement)
        if block_steps:
            raise SystemExit('Documented LaTeX mapping blocks were not found.')
        data = b''.join(output)
    check_bytes(data, entry['size'], entry['sha256'], entry['cache'])
    return data
