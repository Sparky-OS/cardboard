/*
 * Copyright 2026 Daniel Ramos
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.google.cardboard.sdk.qrcode;

import com.google.zxing.BinaryBitmap;
import com.google.zxing.PlanarYUVLuminanceSource;
import com.google.zxing.ReaderException;
import com.google.zxing.common.HybridBinarizer;
import com.google.zxing.qrcode.QRCodeReader;

/** Decodes QR codes locally from the camera's NV21 luminance plane. */
public final class QrCodeDecoder {
  public interface Listener {
    void onQrCodeDetected(String content);
  }

  private final QRCodeReader reader = new QRCodeReader();
  private Listener listener;

  public QrCodeDecoder(Listener listener) {
    this.listener = listener;
  }

  /** Called on the camera worker; QRCodeReader detects rotated codes itself. */
  public void receiveFrame(byte[] data, int width, int height) {
    if (listener == null || width <= 0 || height <= 0 || (long) width * height > data.length) {
      return;
    }
    PlanarYUVLuminanceSource source =
        new PlanarYUVLuminanceSource(data, width, height, 0, 0, width, height, false);
    try {
      String content = reader.decode(new BinaryBitmap(new HybridBinarizer(source))).getText();
      listener.onQrCodeDetected(content);
    } catch (ReaderException e) {
      // An ordinary camera frame need not contain a decodable QR code.
    } finally {
      reader.reset();
    }
  }

  /** Called after the camera worker has stopped. */
  public void release() {
    listener = null;
    reader.reset();
  }
}
