"""Model boundary for cancelling a real restored-history compaction request."""
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

started = threading.Event()
release = threading.Event()
finished = threading.Event()
requests = []


class Model(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.path == '/release':
            release.set()
        body = json.dumps({'summary_started': started.is_set(),
                           'summary_finished': finished.is_set(), 'requests': requests}).encode()
        self.send_response(200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        summary = not data.get('tools')
        requests.append('summary' if summary else 'agent')
        if not summary and data['model'] == 'fixture-compaction-overflow':
            body = json.dumps({'error': {'message': 'maximum context length exceeded',
                                        'code': 'context_length_exceeded'}}).encode()
            self.send_response(400)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.flush()
        if summary:
            started.set()
            # Deliver a late response after the client has acknowledged cancellation.
            release.wait(60)
        content = 'The original evidence remains available; no file changes were made.' if summary else '短请求正常'
        event = {'choices': [{'index': 0, 'delta': {'content': content}, 'finish_reason': 'stop'}]}
        try:
            self.wfile.write(('data: ' + json.dumps(event) + '\n\ndata: [DONE]\n\n').encode())
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            if summary:
                finished.set()
        self.close_connection = True


server = ThreadingHTTPServer(('127.0.0.1', 0), Model)
print(server.server_port, flush=True)
server.serve_forever()
