/*
 * Copyright 2019 Google LLC
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
package com.google.cardboard.sdk;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build.VERSION;
import android.os.Build.VERSION_CODES;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Log;
import android.view.View;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import com.google.cardboard.sdk.qrcode.CardboardParamsUtils;
import com.google.cardboard.sdk.qrcode.QrCodeContentProcessor;
import com.google.cardboard.sdk.qrcode.QrCodeDecoder;
import com.google.cardboard.sdk.qrcode.camera.CameraSource;
import com.google.cardboard.sdk.qrcode.camera.CameraSourcePreview;
import java.io.IOException;

/**
 * Manages the QR code capture activity. It scans permanently with the camera until it finds a valid
 * QR code.
 */
public class QrCodeCaptureActivity extends AppCompatActivity
    implements QrCodeDecoder.Listener, QrCodeContentProcessor.Listener {
  private static final String TAG = QrCodeCaptureActivity.class.getSimpleName();

  // Permission request codes
  private static final int PERMISSIONS_REQUEST_CODE = 2;

  private CameraSource cameraSource;
  private CameraSourcePreview cameraSourcePreview;

  // Flag used to avoid saving the device parameters more than once.
  private boolean qrCodeSaved = false;
  private boolean resumed = false;

  /** Initializes the UI and creates the detector pipeline. */
  @Override
  public void onCreate(Bundle icicle) {
    super.onCreate(icicle);
    setContentView(R.layout.qr_code_capture);

    // Hide system bars
    WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
    WindowInsetsControllerCompat windowInsetsController =
        new WindowInsetsControllerCompat(getWindow(), getWindow().getDecorView());
    windowInsetsController.hide(WindowInsetsCompat.Type.systemBars());
    windowInsetsController.setSystemBarsBehavior(
        WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);

    cameraSourcePreview = findViewById(R.id.preview);
  }

  /**
   * Checks for CAMERA permission.
   *
   * @return whether CAMERA permission is already granted.
   */
  private boolean isCameraEnabled() {
    return ActivityCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
        == PackageManager.PERMISSION_GRANTED;
  }

  /**
   * Checks for WRITE_EXTERNAL_STORAGE permission.
   *
   * @return whether WRITE_EXTERNAL_STORAGE permission is already granted.
   */
  private boolean isWriteExternalStoragePermissionsEnabled() {
    return ActivityCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
        == PackageManager.PERMISSION_GRANTED;
  }

  /** Handles the requests for activity permissions. */
  private void requestPermissions() {
    final String[] permissions =
        VERSION.SDK_INT < VERSION_CODES.Q
            ? new String[] {Manifest.permission.CAMERA, Manifest.permission.WRITE_EXTERNAL_STORAGE}
            : new String[] {Manifest.permission.CAMERA};
    ActivityCompat.requestPermissions(this, permissions, PERMISSIONS_REQUEST_CODE);
  }

  /**
   * Callback for the result from requesting permissions.
   *
   * <p>When Android SDK version is less than Q, both WRITE_EXTERNAL_STORAGE and CAMERA permissions
   * are requested. Otherwise, only CAMERA permission is requested.
   */
  @Override
  public void onRequestPermissionsResult(
      int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    if (requestCode != PERMISSIONS_REQUEST_CODE) {
      return;
    }
    if (isCameraEnabled()
        && (VERSION.SDK_INT >= VERSION_CODES.Q || isWriteExternalStoragePermissionsEnabled())) {
      if (resumed && cameraSource == null) {
        createCameraSource();
        startCameraSource();
      }
      return;
    }
    if (VERSION.SDK_INT < VERSION_CODES.Q) {
      if (!(isCameraEnabled() && isWriteExternalStoragePermissionsEnabled())) {
        Log.i(TAG, getString(R.string.no_permissions));
        Toast.makeText(this, R.string.no_permissions, Toast.LENGTH_LONG).show();
        if (!ActivityCompat.shouldShowRequestPermissionRationale(
                this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
            || !ActivityCompat.shouldShowRequestPermissionRationale(
                this, Manifest.permission.CAMERA)) {
          // Permission denied with checking "Do not ask again".
          Log.i(TAG, "Permission denied with checking \"Do not ask again\".");
          launchPermissionsSettings();
        }
        finish();
      }
    } else {
      if (!isCameraEnabled()) {
        Log.i(TAG, getString(R.string.no_camera_permission));
        Toast.makeText(this, R.string.no_camera_permission, Toast.LENGTH_LONG).show();
        if (!ActivityCompat.shouldShowRequestPermissionRationale(
            this, Manifest.permission.CAMERA)) {
          // Permission denied with checking "Do not ask again". Note that in Android R "Do not ask
          // again" is not available anymore.
          Log.i(TAG, "Permission denied with checking \"Do not ask again\".");
          launchPermissionsSettings();
        }
        finish();
      }
    }
  }

  private void launchPermissionsSettings() {
    Intent intent = new Intent();
    intent.setAction(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
    intent.setData(Uri.fromParts("package", getPackageName(), null));
    startActivity(intent);
  }

  /** Creates and starts the camera. */
  private void createCameraSource() {
    cameraSource = new CameraSource(getApplicationContext(), new QrCodeDecoder(this));
  }

  /** Restarts the camera. */
  @Override
  protected void onResume() {
    super.onResume();
    resumed = true;
    // Checks for CAMERA permission and WRITE_EXTERNAL_STORAGE permission when running on Android P
    // or below. If needed permissions are not granted, requests them.
    if (!(isCameraEnabled()
        && (VERSION.SDK_INT >= VERSION_CODES.Q || isWriteExternalStoragePermissionsEnabled()))) {
      requestPermissions();
      return;
    }

    createCameraSource();
    qrCodeSaved = false;
    startCameraSource();
  }

  /** Stops the camera. */
  @Override
  protected void onPause() {
    resumed = false;
    super.onPause();
    if (cameraSourcePreview != null) {
      cameraSourcePreview.stop();
      cameraSourcePreview.release();
      cameraSource = null;
    }
  }

  /** Starts or restarts the camera source, if it exists. */
  private void startCameraSource() {
    if (cameraSource != null) {
      try {
        cameraSourcePreview.start(cameraSource);
      } catch (IOException e) {
        Log.e(TAG, "Unable to start camera source.", e);
        cameraSource.release();
        cameraSource = null;
      } catch (SecurityException e) {
        Log.e(TAG, "Security exception: ", e);
      }
      Log.i(TAG, "cameraSourcePreview successfully started.");
    }
  }

  /** Callback for when "SKIP" is touched */
  public void skipQrCodeCapture(View view) {
    Log.d(TAG, "QR code capture skipped");

    // Check if there are already saved parameters, if not save Cardboard V1 ones.
    final Context context = getApplicationContext();
    byte[] deviceParams = CardboardParamsUtils.readDeviceParams(context);
    if (deviceParams == null) {
      CardboardParamsUtils.saveCardboardV1DeviceParams(context);
    }
    finish();
  }

  /**
   * Callback for when a QR code is detected.
   *
   * @param qrCode Detected QR code.
   */
  @Override
  public void onQrCodeDetected(String qrCode) {
    runOnUiThread(() -> {
      if (resumed && !isFinishing() && !qrCodeSaved) {
        qrCodeSaved = true;
        new QrCodeContentProcessor(this).processAndSaveQrCode(qrCode, this);
      }
    });
  }

  /**
   * Callback for when a QR code is processed and the parameters are saved in external storage.
   *
   * @param status Whether the parameters were successfully processed and saved.
   */
  @Override
  public void onQrCodeSaved(boolean status) {
    if (status) {
      Log.d(TAG, "Device parameters saved in external storage.");
      cameraSourcePreview.stop();
      nativeIncrementDeviceParamsChangedCount();
      finish();
    } else {
      Log.e(TAG, "Device parameters not saved in external storage.");
    }
    qrCodeSaved = false;
  }

  private native void nativeIncrementDeviceParamsChangedCount();
}
