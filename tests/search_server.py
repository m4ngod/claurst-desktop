"""External model/search HTTP fixture; the desktop and Claurst tools are real."""
import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

slow_started = threading.Event()
steer_started = threading.Event()


class SearchFixture(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_):
        pass

    def reply(self, status, content_type, body):
        encoded = body.encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(encoded)))
        self.end_headers()
        try:
            self.wfile.write(encoded)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        if self.path == '/article':
            self.reply(200, 'text/html', '<html><head><title>搜索后的真实正文</title></head><body><p>银杏预算：73 元</p></body></html>')
        elif self.path == '/steer-started':
            self.reply(200, 'text/plain', 'yes' if steer_started.is_set() else 'no')
        else:
            self.reply(200, 'text/plain', 'yes' if slow_started.is_set() else 'no')

    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        if self.path == '/v1/responses':
            if request.get('tools') != [{'type': 'web_search'}] or request.get('store') is not False or self.headers.get('Authorization') != 'Bearer synthetic-search-key':
                self.reply(400, 'application/json', '{"error":"wrong configured request"}')
                return
            prompt = request.get('input', '')
            if request.get('include') != ['web_search_call.action.sources']:
                self.reply(200, 'application/json', json.dumps({'status': 'completed', 'output': [
                    {'type': 'web_search_call', 'status': 'completed', 'action': {'type': 'search'}}
                ]}))
                return
            if 'fixture-http-error' in prompt:
                self.reply(401, 'application/json', '{"error":"synthetic-search-key"}')
                return
            if 'fixture-oversize' in prompt:
                self.reply(200, 'application/json', ' ' * (2 * 1024 * 1024 + 1))
                return
            if 'fixture-slow-cancel' in prompt:
                slow_started.set()
                time.sleep(3)
            elif 'fixture-slow-steer' in prompt:
                steer_started.set()
                time.sleep(3)
            elif 'fixture-timeout' in prompt:
                time.sleep(62)
            if 'fixture-no-search' in prompt:
                self.reply(200, 'application/json', json.dumps({'status': 'completed', 'output': [
                    {'type': 'message', 'content': [{'type': 'output_text', 'text': 'https://invented.example/'}]}
                ]}))
                return
            if 'fixture-empty' in prompt or 'fixture-invalid-links' in prompt:
                sources = [] if 'fixture-empty' in prompt else [{'type': 'url', 'url': 'javascript:alert(1)'}, {'type': 'url', 'url': 'https://user:password@example.com/'}]
                self.reply(200, 'application/json', json.dumps({'status': 'completed', 'output': [
                    {'type': 'web_search_call', 'status': 'completed', 'action': {'type': 'search', 'sources': sources}}
                ]}))
                return
            if 'fixture-missing-status' in prompt:
                self.reply(200, 'application/json', json.dumps({'status': 'completed', 'output': [
                    {'type': 'web_search_call', 'action': {'type': 'search', 'sources': [{'type': 'url', 'url': 'https://example.org/'}]}}
                ]}))
                return
            candidates = [
                {'type': 'url', 'url': 'https://docs.searxng.org/dev/search_api.html', 'title': 'Search API — SearXNG'},
                {'type': 'url', 'url': 'https://docs.searxng.org/admin/settings/settings_search.html', 'title': 'Search settings'},
            ]
            if 'fixture-chain' in prompt:
                candidates = [{'type': 'url', 'url': f'http://127.0.0.1:{self.server.server_port}/article'}]
            self.reply(200, 'application/json', json.dumps({
                'status': 'incomplete' if 'fixture-incomplete' in prompt else 'completed', 'output': [
                    {'type': 'web_search_call', 'status': 'completed', 'action': {'type': 'search', 'sources': candidates}},
                    {'type': 'message', 'content': [{'type': 'output_text', 'text': 'Unverified generated answer https://invented.example/'}]},
                ]}))
            return
        if self.path != '/v1/chat/completions':
            self.reply(404, 'text/plain', 'missing')
            return
        message = request['messages'][-1]
        text = message['content']
        if message['role'] == 'user' and 'search-fixture:' in text:
            arguments, _ = json.JSONDecoder().raw_decode(text.split('search-fixture:', 1)[1].lstrip())
            delta = {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'search-1', 'type': 'function',
                'function': {'name': 'WebSearch', 'arguments': json.dumps(arguments)}}]}
            reason = 'tool_calls'
        else:
            result = {}
            if message['role'] == 'tool':
                try:
                    result = json.loads(text)
                    text = result.get('content', text)
                except (ValueError, TypeError):
                    pass
            if result.get('search_result', {}).get('query') == 'fixture-chain':
                url = result['search_result']['candidates'][0]['url']
                delta = {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'read-2', 'type': 'function',
                    'function': {'name': 'WebFetch', 'arguments': json.dumps({'url': url})}}]}
                reason = 'tool_calls'
            else:
                delta = {'role': 'assistant', 'content': text}
                reason = 'stop'
        chunks = [{'choices': [{'index': 0, 'delta': delta, 'finish_reason': None}]},
                  {'choices': [{'index': 0, 'delta': {}, 'finish_reason': reason}]}]
        body = ''.join('data: ' + json.dumps(c, ensure_ascii=False) + '\n\n' for c in chunks) + 'data: [DONE]\n\n'
        self.reply(200, 'text/event-stream', body)


server = ThreadingHTTPServer(('127.0.0.1', 0), SearchFixture)
print(server.server_port, flush=True)
server.serve_forever()
