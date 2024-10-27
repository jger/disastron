/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved. This software and associated documentation files
/// (the "Software") may not be used, copied, modified, merged, published,
/// distributed, sublicensed, or sold, without the prior written permission
/// of the copyright holder.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
/// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
/// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
/// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
/// DEALINGS IN THE SOFTWARE.
/// ***************************************************************************

library;

import 'dart:developer';

import 'package:auto_route/auto_route.dart';
import 'package:disastron/features/get_photo/providers/image_picker_provider.dart';
import 'package:disastron/shared/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

@RoutePage()
class GetPhotoPage extends ConsumerWidget {
  const GetPhotoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ImagePicker imagePicker = ref.watch(imagePickerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take a photo or select one from the gallery'),
      ),
      drawer: const AppDrawer(),
      body: Center(
        child: Column(
          children: [
            // Take a photo from the gallery
            ElevatedButton(
              onPressed: () async {
                final XFile? media = await imagePicker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 2000,
                  maxHeight: 2000,
                  imageQuality: 100,
                );
                log('Image path: ${media?.path ?? '-'}', name: 'GetPhoto');
              },
              child: const Text('Photo from gallery'),
            ),

            // Take a photo with the camera
            ElevatedButton(
              onPressed: () async {
                // Take Photo
                final XFile? media = await imagePicker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 2000,
                  maxHeight: 2000,
                  imageQuality: 100,
                );
                log('Image path: ${media?.path ?? '-'}', name: 'GetPhoto');
              },
              child: const Text('Take a photo'),
            ),
          ],
        ),
      ),
    );
  }
}
