/* Copyright 2026 Daniel Ramos. SPDX-License-Identifier: Apache-2.0 */
package com.google.cardboard.sdk.qrcode;

import static org.junit.Assert.*;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.junit.Test;

public class QrCodeDecoderTest {
  @Test public void decodesAllCameraRotationsWithoutServices() throws Exception {
    String content = "https://google.com/cardboard/cfg?p=QR_PROOF";
    BitMatrix matrix = new QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, 480, 480);
    List<String> results = new ArrayList<>();
    QrCodeDecoder decoder = new QrCodeDecoder(results::add);
    for (int turn = 0; turn < 4; turn++) {
      byte[] nv21 = new byte[480 * 480 * 3 / 2];
      Arrays.fill(nv21, (byte)128);
      for (int y = 0; y < 480; y++) {
        for (int x = 0; x < 480; x++) nv21[y * 480 + x] = (byte)(matrix.get(x,y) ? 16 : 235);
      }
      decoder.receiveFrame(nv21, 480, 480);
      assertEquals(turn + 1, results.size());
      assertEquals(content, results.get(turn));
      matrix.rotate90();
    }
  }

  @Test public void blankTruncatedAndReleasedFramesDoNotProduceResults() throws Exception {
    List<String> results = new ArrayList<>();
    QrCodeDecoder decoder = new QrCodeDecoder(results::add);
    byte[] pixels = new byte[256 * 256];
    Arrays.fill(pixels, (byte)235);
    decoder.receiveFrame(pixels, 256, 256);
    decoder.receiveFrame(new byte[10], 256, 256);
    decoder.receiveFrame(pixels, 0, 256);
    assertTrue(results.isEmpty());
    BitMatrix matrix = new QRCodeWriter().encode("not a viewer", BarcodeFormat.QR_CODE, 256, 256);
    for (int y = 0; y < 256; y++) for (int x = 0; x < 256; x++)
      pixels[y * 256 + x] = (byte)(matrix.get(x,y) ? 16 : 235);
    decoder.receiveFrame(pixels, 256, 256);
    assertEquals(Arrays.asList("not a viewer"), results);
    decoder.release();
    decoder.receiveFrame(pixels, 256, 256);
    assertEquals(1, results.size());
  }
}
