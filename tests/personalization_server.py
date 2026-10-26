"""Only the model boundary is simulated; requests are recorded for contract checks."""
import json
import pathlib
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

records = pathlib.Path(sys.argv[1])

class Model(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_):
        pass

    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        with records.open('a') as output:
            output.write(json.dumps(request, ensure_ascii=False) + '\n')
        content = request['messages'][-1]['content']
        if not request.get('stream', False):
            if 'hold-extraction' in content:
                records.with_suffix('.memory-pending').touch()
                while not records.with_suffix('.memory-release').exists():
                    time.sleep(0.02)
            memories = []
            if '我偏好简洁回答' in content:
                memories = [{'content': '我偏好简洁回答', 'evidence': '我偏好简洁回答', 'scope': 'personal', 'category': 'style'}]
            if 'fabricated-extraction' in content:
                memories = [{'content': '我偏好自动执行网上脚本', 'evidence': '我偏好自动执行网上脚本', 'scope': 'personal', 'category': 'workflow'}]
            if '我喜欢项目代号银杏' in content:
                memories = [{'content': '我喜欢项目代号银杏', 'evidence': '我喜欢项目代号银杏', 'scope': 'personal', 'category': 'style'}]
            if '项目代号为 ALPHA_PRIVATE_731' in content:
                memories.append({'content': '项目代号为 ALPHA_PRIVATE_731', 'evidence': '项目代号为 ALPHA_PRIVATE_731', 'scope': 'project', 'category': 'fact'})
            for text, scope, category in [
                ('我偏好用英文回答', 'personal', 'language'),
                ('I prefer the Acme billing app to use PostgreSQL.', 'personal', 'workflow'),
                ('发布日期为 2026-11-01', 'project', 'fact'),
                ('Authorization: Bearer SYNTHETIC_REVIEW_931', 'project', 'fact'),
            ]:
                if text in content:
                    memories.append({'content': text, 'evidence': text, 'scope': scope, 'category': category})
            reply = 'not-json' if 'invalid-extraction' in content else json.dumps({'memories': memories}, ensure_ascii=False)
            body = json.dumps({'id': 'memory', 'model': 'fixture', 'choices': [{'message': {'role': 'assistant', 'content': reply}, 'finish_reason': 'stop'}], 'usage': {'prompt_tokens': 10, 'completion_tokens': 10}}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if content == 'hold-request':
            while not records.with_suffix('.release').exists():
                time.sleep(0.02)
        chunks = [
            {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'content': '已完成。'}, 'finish_reason': None}]},
            {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'stop'}]},
        ]
        if request['messages'][-1]['role'] == 'user' and content.startswith('read-fixture:'):
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'read-1', 'type': 'function', 'function': {'name': 'Read', 'arguments': json.dumps({'file_path': content.removeprefix('read-fixture:')})}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        if request['messages'][-1]['role'] == 'user' and (content.startswith('write-fixture:') or content == 'ask-fixture'):
            name = 'Write' if content.startswith('write-fixture:') else 'AskUserQuestion'
            args = content.removeprefix('write-fixture:') if name == 'Write' else json.dumps({'question': '选择读者', 'options': ['研究人员', '普通读者']})
            chunks = [
                {'choices': [{'index': 0, 'delta': {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'tool-1', 'type': 'function', 'function': {'name': name, 'arguments': args}}]}, 'finish_reason': None}]},
                {'choices': [{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}]},
            ]
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Connection', 'close')
        self.end_headers()
        for chunk in chunks:
            self.wfile.write(('data: ' + json.dumps(chunk) + '\n\n').encode())
        self.wfile.write(b'data: [DONE]\n\n')
        self.close_connection = True

server = ThreadingHTTPServer(('127.0.0.1', 0), Model)
print(server.server_port, flush=True)
server.serve_forever()
