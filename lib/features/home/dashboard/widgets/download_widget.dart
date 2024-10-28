import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class DownloadWidget extends StatefulWidget {
  const DownloadWidget({super.key});

  @override
  DownloadWidgetState createState() => DownloadWidgetState();
}

class DownloadWidgetState extends State<DownloadWidget> {
  bool _isDownloading = false;
  double _progress = 0;
  String _filePath = '';

  Future<void> _downloadFile() async {
    setState(() {
      _isDownloading = true;
    });

    final dio = Dio();
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/model.tar.gz';

    try {
      await dio.download(
        'https://huggingface.co/google/gemma-1.1-2b-it-tflite/resolve/main/gemma-1.1-2b-it-cpu-int4.bin?download=true',
        filePath,
        // options: Options(
        //   headers: {
        //     'Authorization': 'Kaggle <YOUR_USERNAME>:<YOUR_KEY>',
        //   },
        // ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );
      setState(() {
        _filePath = filePath;
      });
    } catch (e) {
      log('Download failed: $e');
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Model'),
      ),
      body: Center(
        child: _isDownloading
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: _progress),
            const SizedBox(height: 20),
            Text('${(_progress * 100).toStringAsFixed(0)}%'),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: _downloadFile,
              child: const Text('Download Language Model'),
            ),
            if (_filePath.isNotEmpty) Text('File saved at: $_filePath'),
          ],
        ),
      ),
    );
  }
}