"""Only external model/search/web HTTP is replaced; no fixture file I/O."""
import base64
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class ResearchFixture(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, content_type, text):
        body = text.encode()
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self.reply('text/html', '<html><head><title>合成研究方法</title></head>'
                   '<body><p>缺失金额不得当作零填充。该页面仅为合成测试资料。</p></body></html>')

    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        if self.path == '/v1/responses':
            self.reply('application/json', json.dumps({'status': 'completed', 'output': [
                {'type': 'web_search_call', 'status': 'completed', 'action': {
                    'type': 'search', 'sources': [{'type': 'url',
                        'url': f'http://127.0.0.1:{self.server.server_port}/method'}]}}]}))
            return
        messages = request['messages']
        calls = [call for message in messages for call in message.get('tool_calls', [])
                 if call['id'].startswith('research-')]
        step = len(calls)
        results = {message['tool_call_id']: message['content'] for message in messages
                   if message['role'] == 'tool'}
        def result(index):
            return json.loads(results[f'research-{index}'])
        plan = [
            ('Read', {'file_path': 'notes.md'}),
            ('Read', {'file_path': 'report.pdf'}),
            ('Read', {'file_path': 'report.docx'}),
            ('AnalyzeTable', {'file_path': 'sales.xlsx', 'action': 'read', 'sheet': '交易'}),
            ('AnalyzeTable', {'file_path': 'sales.xlsx', 'action': 'group_sum',
                              'sheet': '交易', 'group_column': 'A', 'value_column': 'B'}),
            ('AnalyzeTable', {'file_path': 'sales.csv', 'action': 'group_sum',
                              'group_column': 'A', 'value_column': 'B'}),
            ('RecognizeText', {'file_path': 'scanned.pdf', 'limit': 2}),
            ('RecognizeText', {'file_path': 'printed.png'}),
            ('WebSearch', {'query': '合成样本 缺失金额处理'}),
        ]
        try:
            if step < len(plan):
                name, arguments = plan[step]
            elif step == 9:
                name, arguments = 'WebFetch', {'url': result(8)['search_result']['candidates'][0]['url']}
            elif step == 10:
                name, arguments = 'AskUserQuestion', {'question': '报告面向哪类读者？',
                                                       'options': ['研究人员', '普通读者']}
            elif step in (11, 12, 13):
                # References are assembled from actual tool returns, not invented IDs.
                webpage = result(9)['web_source']
                if step == 11:
                    path = 'paper/main.tex'
                    content = r'''\documentclass[UTF8,fontset=claurst]{ctexart}
\usepackage[a4paper,margin=25mm]{geometry}
\usepackage{booktabs}
\begin{document}
\section{混合素材合成研究}
\input{sections/results.tex}
\begin{thebibliography}{9}
\bibitem{method} 合成研究方法。网页来源编号：''' + webpage['id'] + r'''。
\end{thebibliography}
\end{document}
'''
                elif step == 12:
                    # Retain evidence from every real format in the delivered source.
                    assertions = [(0, '银杏'), (1, '73'), (2, '80'), (4, '合计=13'),
                                  (5, '合计=7'), (6, 'SECOND-418'), (7, 'SCAN-731')]
                    if not all(value in result(index)['content'] for index, value in assertions):
                        raise ValueError('mixed-format tool evidence missing')
                    path = 'paper/sections/results.tex'
                    content = r'''面向研究人员，以下均为合成测试资料，不能推断真实业务结论。
文本 notes.md 第2行记录项目银杏。文字 PDF report.pdf 第1页记录预算73元，
Word report.docx 第2段记录预算80元；二者数值冲突，版本关系未确认，差异原因缺少依据。

表格 sales.xlsx 的交易工作表与 sales.csv 均使用 A2:A5 分组、B2:B5 十进制求和：
\begin{center}\begin{tabular}{lr}\toprule 区域 & 合计 \\\midrule
华东 & 13 \\ 华西 & 7 \\\bottomrule\end{tabular}\end{center}
华西有一个金额缺失，未填零；样本不能推算总体。
扫描 PDF 第2页读到 SECOND-418，图片识别读到 SCAN-731；
识别区域和置信信息见来源记录，公式与表格结构尚未验证。
网页方法要求保留缺失金额\cite{method}。
目前没有真实样本量和总体定义，结论仅限合成样本。
'''
                else:
                    path = 'paper/sources.md'
                    content = '# 实际读取依据\n\n' + '\n\n'.join(
                        f'## 材料 {i}\n\n' + results[f'research-{i}'] for i in range(10))
                    content += '\n\n## 读者确认\n\n' + results['research-10']
                name, arguments = 'Write', {'file_path': path, 'content': content,
                                            'reason': '保存混合素材报告与实际来源，保留缺失依据'}
            elif step == 14:
                name, arguments = 'CompileLaTeX', {'file_path': 'paper/main.tex'}
            elif step in (15, 16):
                path = result(14)['latex_artifact']['pdf_path']
                name, arguments = ('Read' if step == 15 else 'ReadImage'), {'file_path': path, 'offset': 1}
            else:
                images = [part for message in messages if isinstance(message.get('content'), list)
                          for part in message['content'] if part.get('type') == 'image_url']
                pixels = [base64.b64decode(part['image_url']['url'].split(',', 1)[1]) for part in images]
                valid = any(data.startswith((b'\x89PNG\r\n\x1a\n', b'\xff\xd8')) and len(data) > 1000 for data in pixels)
                if not valid:
                    raise ValueError('actual rendered PDF pixels missing from model request')
                self.finish({'content': '收到实际 PDF 页面像素。固定模型替身不能评价版面，页面布局未核对；不能据此宣称完整交付。'}, 'stop')
                return
            self.finish({'tool_calls': [{'index': 0, 'id': f'research-{step}', 'type': 'function',
                         'function': {'name': name, 'arguments': json.dumps(arguments)}}]}, 'tool_calls')
        except (KeyError, ValueError, TypeError) as error:
            self.finish({'content': '研究流程缺少实际证据：' + str(error)}, 'stop')

    def finish(self, delta, reason):
        chunks = [{'choices': [{'index': 0, 'delta': {'role': 'assistant', **delta}, 'finish_reason': None}]},
                  {'choices': [{'index': 0, 'delta': {}, 'finish_reason': reason}]}]
        self.reply('text/event-stream', ''.join('data: ' + json.dumps(chunk, ensure_ascii=False) + '\n\n'
                                               for chunk in chunks) + 'data: [DONE]\n\n')


server = ThreadingHTTPServer(('127.0.0.1', 0), ResearchFixture)
print(server.server_port, flush=True)
server.serve_forever()
