"""Deterministic model boundary only; Claurst and the task service remain real."""
import json
import time
from vision_fixture import image_probe_reply
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Model(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_):
        pass

    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        if self.path != '/v1/chat/completions':
            self.send_error(404)
            return
        content = request['messages'][-1]['content']
        if isinstance(content, list):
            content = '\n'.join(part['text'] for part in content if part.get('type') == 'text')
        if request['messages'][-1]['role'] == 'tool':
            try:
                result = json.loads(content)
                if isinstance(result, dict) and 'source' in result:
                    content = result['content']
            except (ValueError, TypeError):
                pass
        if content == 'simulate-auth-error':
            body = json.dumps({'error': {'message': 'invalid test-only key', 'type': 'authentication_error'}}).encode()
            self.send_response(401)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if request['model'] == 'fixture-slow-tool-check' and request['messages'][-1]['role'] == 'tool':
            time.sleep(95)
        if request['model'] == 'fixture-reject-image' and isinstance(request['messages'][-1]['content'], list) and any(part.get('type') == 'image_url' for part in request['messages'][-1]['content']):
            body = json.dumps({'error': {'message': 'Image input is not supported by this test model', 'type': 'invalid_request_error'}}).encode()
            self.send_response(400)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        # The fixture does not infer task success or touch workspace files.
        chunks = [
            {'id': 'fixture', 'model': 'fixture-model', 'choices': [{'index': 0, 'delta': {'role': 'assistant', 'content': '测试回复：'}, 'finish_reason': None}]},
            {'id': 'fixture', 'model': 'fixture-model', 'choices': [{'index': 0, 'delta': {'content': content}, 'finish_reason': None}]},
            {'id': 'fixture', 'model': 'fixture-model', 'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'stop'}]},
        ]
        if content.startswith('这是图像能力检查。'):
            chunks[0]['choices'][0]['delta']['content'] = ''
            chunks[1]['choices'][0]['delta']['content'] = ('无法识别' if request['model'] == 'fixture-wrong-image'
                else image_probe_reply(request['messages'][-1]['content']))
        elif isinstance(request['messages'][-1]['content'], list) and any(part.get('type') == 'image_url' for part in request['messages'][-1]['content']):
            chunks[0]['choices'][0]['delta']['content'] = ''
            pending = set()
            valid = True
            for message in request['messages']:
                if pending and message['role'] != 'tool':
                    valid = False
                pending.update(call['id'] for call in message.get('tool_calls', []))
                if message['role'] == 'tool':
                    pending.discard(message.get('tool_call_id'))
            pictures = [part for part in request['messages'][-1]['content'] if part.get('type') == 'image_url']
            chunks[1]['choices'][0]['delta']['content'] = ('图像颜色：' + '；'.join(
                image_probe_reply([part], ((800, 240), (1600, 480))) for part in pictures)) if valid and not pending else '工具消息顺序无效'
        if content.startswith('view-image-fixture:'):
            arguments = content.removeprefix('view-image-fixture:')
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'image-read-1', 'type': 'function', 'function': {'name': 'ReadImage', 'arguments': arguments}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        if content == 'view-batch-fixture':
            calls = [
                {'index': index, 'id': f'image-batch-{index}', 'type': 'function', 'function': {'name': 'ReadImage', 'arguments': json.dumps(arguments)}}
                for index, arguments in enumerate([{'file_path': 'colors.png'}, {'file_path': 'colors.pdf', 'offset': 1}])
            ]
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': calls}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        if content == 'history-fixture':
            writes = sum(call.get('function', {}).get('name') == 'Write'
                         for message in request['messages']
                         for call in message.get('tool_calls', []))
            chunks[0]['choices'][0]['delta']['content'] = '历史写入次数：'
            chunks[1]['choices'][0]['delta']['content'] = str(writes)
        if content == 'recovered-history-fixture':
            history = json.dumps(request['messages'][:-1], ensure_ascii=False)
            found = all(value in history for value in ['银杏', '预算：73 元', 'result.txt', '完成'])
            chunks[0]['choices'][0]['delta']['content'] = ''
            chunks[1]['choices'][0]['delta']['content'] = '历史包含银杏预算与已完成成果' if found else '缺少历史'
        if content.startswith('private-history-fixture:'):
            chunks[0]['choices'][0]['delta']['reasoning_content'] = 'HIDDEN_REASONING_MUST_NOT_PERSIST'
        if content.startswith('has-history-file:'):
            name = content.removeprefix('has-history-file:')
            found = name in json.dumps(request['messages'][:-1], ensure_ascii=False)
            chunks[0]['choices'][0]['delta']['content'] = ''
            chunks[1]['choices'][0]['delta']['content'] = '历史保留：' + name if found else '缺少历史'
        if content == 'simulate-split-secret':
            chunks[0]['choices'][0]['delta']['content'] = 'test-'
            chunks[1]['choices'][0]['delta']['content'] = 'only'
        if request['messages'][-1]['role'] == 'user' and content.startswith('read-fixture:'):
            # Ask the real tool to read; the fixture has no filesystem access.
            arguments = json.dumps({'file_path': content.removeprefix('read-fixture:')})
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'read-1', 'type': 'function', 'function': {'name': 'Read', 'arguments': arguments}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        if request['messages'][-1]['role'] == 'user' and content.startswith('read-options-fixture:'):
            arguments = content.removeprefix('read-options-fixture:')
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'document-read-1', 'type': 'function', 'function': {'name': 'Read', 'arguments': arguments}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        if request['messages'][-1]['role'] == 'user' and content.startswith('请调用 Read 读取 connection-probe.txt'):
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'probe-1', 'type': 'function', 'function': {'name': 'Read', 'arguments': '{"file_path":"connection-probe.txt"}'}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        if request['messages'][-1]['role'] == 'user' and content.startswith('read-stream-fixture:'):
            # Observed Qwen wire shape: continuation chunks carry an empty id.
            arguments = json.dumps({'file_path': content.removeprefix('read-stream-fixture:')})
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'read-stream-1', 'type': 'function', 'function': {'name': 'Read', 'arguments': ''}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {'tool_calls': [{'index': 0, 'id': '', 'function': {'arguments': arguments[:10]}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {'tool_calls': [{'index': 0, 'id': '', 'function': {'arguments': arguments[10:]}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        if request['messages'][-1]['role'] == 'user' and content.startswith('write-fixture:'):
            arguments = content.removeprefix('write-fixture:')
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'write-1', 'type': 'function', 'function': {'name': 'Write', 'arguments': arguments}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        if request['messages'][-1]['role'] == 'user' and content.startswith(('move-fixture:', 'delete-fixture:', 'command-fixture:', 'table-fixture:', 'ocr-fixture:')):
            name = {'move-fixture': 'Move', 'delete-fixture': 'Delete', 'command-fixture': 'Bash', 'table-fixture': 'AnalyzeTable', 'ocr-fixture': 'RecognizeText'}[content.split(':', 1)[0]]
            arguments = content.split(':', 1)[1]
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'organize-1', 'type': 'function', 'function': {'name': name, 'arguments': arguments}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        if request['messages'][-1]['role'] == 'user' and content.startswith(('write-large-fixture:', 'write-oversized-fixture:')):
            size = 33 if content.startswith('write-oversized-fixture:') else 16
            arguments = json.dumps({'file_path': content.split(':', 1)[1], 'content': 'x' * (size * 1024 * 1024)})
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'large-write-1', 'type': 'function', 'function': {'name': 'Write', 'arguments': arguments}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        slow_write = request['messages'][-1]['role'] == 'user' and content.startswith('slow-write-fixture:')
        batch_question = content.startswith('write-then-ask-fixture:')
        if request['messages'][-1]['role'] == 'user' and (content == 'ask-fixture' or batch_question):
            arguments = json.dumps({'question': '报告面向哪类读者？', 'options': ['研究人员', '普通读者']}, ensure_ascii=False)
            calls = [{'index': 0, 'id': 'ask-1', 'type': 'function', 'function': {'name': 'AskUserQuestion', 'arguments': arguments}}]
            if batch_question:
                calls[0]['index'] = 1
                calls.insert(0, {'index': 0, 'id': 'batch-write', 'type': 'function', 'function': {'name': 'Write', 'arguments': json.dumps({'file_path': content.removeprefix('write-then-ask-fixture:'), 'content': '先完成的写入\n'})}})
                calls.append({'index': 2, 'id': 'late-read', 'type': 'function', 'function': {'name': 'Read', 'arguments': '{"file_path":"after-stop.txt"}'}})
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': calls}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        if slow_write:
            arguments = json.dumps({'file_path': content.removeprefix('slow-write-fixture:'), 'content': '停止后不得写入'})
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'content': '等待停止'}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {'tool_calls': [{'index': 0, 'id': 'late-write', 'type': 'function', 'function': {'name': 'Write', 'arguments': arguments}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        # Multi-step coding response uses only the actual tool messages.
        # It never reads or writes the workspace from this HTTP process.
        last_user = max((i for i, message in enumerate(request['messages'])
                         if message['role'] == 'user'), default=-1)
        coding_request = request['messages'][last_user]['content'] if last_user >= 0 else ''
        if isinstance(coding_request, str) and coding_request.startswith('coding-fixture:'):
            results = [message['content'] for message in request['messages'][last_user + 1:]
                       if message['role'] == 'tool']
            step = len(results)
            if step < 4:
                if step == 0:
                    name, arguments = 'Read', {'file_path': 'app/state.py'}
                elif step == 1:
                    name, arguments = 'Read', {'file_path': 'checks/test_state.py'}
                elif step == 2:
                    source = json.loads(results[0])['content']
                    original = ''.join(line.partition('\t')[2] for line in source.splitlines(keepends=True))
                    changed = original.replace('return SearchState(status=status, sort_order=self.sort_order)',
                                               'return replace(self, status=status)')
                    if coding_request == 'coding-fixture:broken-search':
                        changed = original + '\n# 保留的未完成尝试\n'
                    name, arguments = 'Write', {'file_path': 'app/state.py', 'content': changed, 'reason': '切换状态时沿用当前搜索词和排序，只替换状态字段。'}
                else:
                    name, arguments = 'Bash', {'command': '/Library/Developer/CommandLineTools/usr/bin/python3 -B -m unittest discover -s checks -v', 'check_name': '搜索条件回归'}
                chunks = [
                    {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'coding-' + str(step), 'type': 'function', 'function': {'name': name, 'arguments': json.dumps(arguments)}}]}, 'finish_reason': None}]},
                    {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
                ]
            elif coding_request == 'coding-fixture:broken-search':
                chunks[0]['choices'][0]['delta']['content'] = ''
                chunks[1]['choices'][0]['delta']['content'] = '已验证完成，所有检查通过。'
        body = ''.join('data: ' + json.dumps(chunk, ensure_ascii=False) + '\n\n' for chunk in chunks) + 'data: [DONE]\n\n'
        body = body.encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if slow_write:
            try:
                first = ('data: ' + json.dumps(chunks[0], ensure_ascii=False) + '\n\n').encode()
                self.wfile.write(first)
                self.wfile.flush()
                time.sleep(1)
                self.wfile.write(body[len(first):])
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
            return
        self.wfile.write(body)
        self.wfile.flush()


server = ThreadingHTTPServer(('127.0.0.1', 0), Model)
print(server.server_port, flush=True)
server.serve_forever()
