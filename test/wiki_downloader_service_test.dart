import 'package:disastron/features/wiki/data/wiki_downloader_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WikiDownloaderService HTML Sanitization', () {
    const service = WikiDownloaderService();

    test('should completely strip script tags', () {
      const inputHtml = '''
        <html>
          <head>
            <script type="text/javascript">alert("malicious js");</script>
            <title>Test Page</title>
          </head>
          <body>
            <h1>Hello World</h1>
            <script src="https://example.com/external.js"></script>
          </body>
        </html>
      ''';

      final outputHtml = service.cleanHtml(inputHtml);

      expect(outputHtml, isNot(contains('<script')));
      expect(outputHtml, isNot(contains('alert("malicious js")')));
      expect(outputHtml, isNot(contains('external.js')));
      expect(outputHtml, contains('<h1>Hello World</h1>'));
    });

    test('should strip inline javascript event handlers', () {
      const inputHtml = '''
        <html>
          <body>
            <button onclick="doSomething()" onmouseover="hover()">Click Me</button>
            <div onload="load()" class="my-div">Content</div>
          </body>
        </html>
      ''';

      final outputHtml = service.cleanHtml(inputHtml);

      expect(outputHtml, isNot(contains('onclick')));
      expect(outputHtml, isNot(contains('onmouseover')));
      expect(outputHtml, isNot(contains('onload')));
      expect(outputHtml, contains('class="my-div"'));
      expect(outputHtml, contains('Click Me'));
    });

    test('should replace javascript: links with #', () {
      const inputHtml = '''
        <html>
          <body>
            <a href="javascript:void(0)">Void Link</a>
            <a href="javascript:alert(1)">Alert Link</a>
            <a href="https://example.com">Normal Link</a>
          </body>
        </html>
      ''';

      final outputHtml = service.cleanHtml(inputHtml);

      expect(outputHtml, isNot(contains('javascript:')));
      expect(outputHtml, contains('href="#"'));
      expect(outputHtml, contains('href="https://example.com"'));
    });
  });
}
