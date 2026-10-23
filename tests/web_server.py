"""Only the model and external HTTP boundary; all runtime tools remain real."""
import json
import time
import html
import threading

slow_started = threading.Event()
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class WebFixture(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_):
        pass

    def reply(self, status, content_type, body):
        body = body.encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == '/large-message':
            paragraphs = ''.join(f'<p>第 {i} 段：银杏项目预算 73 元，这是用于核对协议传输顺序的合成材料。</p>' for i in range(1, 401))
            self.reply(200, 'text/html; charset=utf-8', '<html><head><title>长网页回归</title></head><body>' + paragraphs + '</body></html>')
        elif self.path == '/article':
            self.reply(200, 'text/html; charset=utf-8', '''<!doctype html><html><head><title>银杏 &amp; 预算</title>
<style>脚本伪造数据</style></head><body><main><h1>银杏项目</h1>
<p>预算：<strong>73</strong> 元</p><p>核对码：WEB-731</p><script>脚本伪造数据</script></main></body></html>''')
        elif self.path == '/privacy':
            key = html.escape('fixture/quote"slash\\end')
            self.reply(200, 'text/html', f'<html><head><title>{key}</title></head><body><p>{key}</p></body></html>')
        elif self.path == '/empty':
            self.reply(200, 'text/html', '<html><head><title>Empty</title></head><body><script>not evidence</script></body></html>')
        elif self.path == '/large':
            self.reply(200, 'text/plain', 'a' * (2 * 1024 * 1024 + 1))
        elif self.path == '/binary':
            self.reply(200, 'application/octet-stream', 'not text evidence')
        elif self.path == '/started':
            self.reply(200, 'text/plain', 'yes' if slow_started.is_set() else 'no')
        elif self.path == '/slow-cancel':
            slow_started.set()
            time.sleep(3)
            try:
                self.reply(200, 'text/plain', 'must not become a source after Stop')
            except (BrokenPipeError, ConnectionResetError):
                pass
        elif self.path == '/slow':
            time.sleep(32)
            try:
                self.reply(200, 'text/plain', 'too late')
            except (BrokenPipeError, ConnectionResetError):
                pass
        else:
            self.reply(404, 'text/plain', 'missing')

    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        if self.path != '/v1/chat/completions':
            self.reply(404, 'text/plain', 'missing')
            return
        message = request['messages'][-1]
        text = message['content']
        if message['role'] == 'tool':
            try:
                text = json.loads(text).get('content', text)
            except (ValueError, TypeError):
                pass
        if message['role'] == 'user' and text.startswith('fetch-fixture:'):
            delta = {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'fetch-1', 'type': 'function',
                'function': {'name': 'WebFetch', 'arguments': text.removeprefix('fetch-fixture:')}}]}
            reason = 'tool_calls'
        else:
            delta = {'role': 'assistant', 'content': text}
            reason = 'stop'
        chunks = [{'choices': [{'index': 0, 'delta': delta, 'finish_reason': None}]},
                  {'choices': [{'index': 0, 'delta': {}, 'finish_reason': reason}]}]
        body = ''.join('data: ' + json.dumps(chunk, ensure_ascii=False) + '\n\n' for chunk in chunks) + 'data: [DONE]\n\n'
        self.reply(200, 'text/event-stream', body)


server = ThreadingHTTPServer(('127.0.0.1', 0), WebFixture)
print(server.server_port, flush=True)
server.serve_forever()
