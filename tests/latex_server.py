"""Replace only the model HTTP boundary; the LaTeX compiler and files are real."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class LatexFixture(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        message = request['messages'][-1]
        text = message['content']
        if message['role'] == 'user' and text.startswith('latex-fixture:'):
            delta = {'role': 'assistant', 'tool_calls': [{'index': 0, 'id': 'latex-1', 'type': 'function',
                'function': {'name': 'CompileLaTeX', 'arguments': text.removeprefix('latex-fixture:')}}]}
            reason = 'tool_calls'
        else:
            delta = {'role': 'assistant', 'content': text}
            reason = 'stop'
        chunks = [{'choices': [{'index': 0, 'delta': delta, 'finish_reason': None}]},
                  {'choices': [{'index': 0, 'delta': {}, 'finish_reason': reason}]}]
        body = (''.join('data: ' + json.dumps(chunk, ensure_ascii=False) + '\n\n' for chunk in chunks)
                + 'data: [DONE]\n\n').encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


server = ThreadingHTTPServer(('127.0.0.1', 0), LatexFixture)
print(server.server_port, flush=True)
server.serve_forever()
