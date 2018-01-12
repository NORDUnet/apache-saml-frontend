#!/usr/bin/env python2.7

import SimpleHTTPServer
import SocketServer
import logging
import argparse
import json
import urlparse


class GetHandler(SimpleHTTPServer.SimpleHTTPRequestHandler):

    def do_GET(self):
        logging.error(self.headers)
        self.send_response(200)
        handlers = {'html': self.html,
                    'json': self.json}

        if not self.format(handlers):
            # Default fallback
            self.html()
        # Extra newline to make it nice in curl
        self.wfile.write("\n")

    def html(self):
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        html_header = '<dt>{}</dt><dd>{}</dd>'
        out_headers = '\n'.join([html_header.format(k, v) for k, v in self.headers.items()])
        self.wfile.write('<html><body>\n<p>IP: {}</p>\n<p>Headers:</p>\n{}\n</body></html>'.format(self.client_address, out_headers))
        return True

    def json(self):
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        out = {'ip': self.client_address,
               'headers': dict(self.headers.items())}
        self.wfile.write(json.dumps(out))
        return True

    def format(self, handlers):
        result = False
        _format = self.query('format')
        if _format and handlers.get(_format[0]):
            result = handlers[_format[0]]()
        else:
            # naive accept implementation, does not handle weights
            result = any((v() for k, v in handlers.items() if k in self.accept()))

        return result

    def query(self, param):
        url = urlparse.urlparse(self.path)
        query = urlparse.parse_qs(url.query)
        return query.get(param)

    def accept(self):
        return self.headers.get('accept', '')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-p', '--port', help='Set the port to listen on (default 8443)', default=8443, type=int)
    args = parser.parse_args()
    httpd = SocketServer.TCPServer(("", args.port), GetHandler)
    httpd.serve_forever()
