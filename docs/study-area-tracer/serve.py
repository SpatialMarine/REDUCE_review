from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Timer
import webbrowser

# Serve the tool and its local PDF.js assets on this computer only.
handler = partial(SimpleHTTPRequestHandler, directory=str(Path(__file__).resolve().parent))
with ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
    url = f"http://127.0.0.1:{server.server_port}/"
    print(f"Open {url} in your browser. Keep this window open while tracing.", flush=True)
    Timer(0.5, webbrowser.open, args=[url]).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
