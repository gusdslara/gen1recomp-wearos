package com.wearports.firered;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewTreeObserver;

import java.io.File;
import java.io.FileOutputStream;

import org.libsdl.app.SDLActivity;
import org.love2d.android.GameActivity;

/**
 * Wear OS host for the FireRed port.
 *
 * Everything gameplay-related (gestures, round-screen layout, power saving)
 * lives in Lua (src/core/WatchGestures.lua, src/core/Watch.lua).  This class
 * only adapts the watch's hardware to what LOVE already understands:
 *
 *  - Boots straight into FireRed (gen1recomp++://launch?game=firered) instead
 *    of the 1024x768 desktop-style launcher.  Without an imported ROM the
 *    app falls back to the launcher by itself.
 *  - Rotating bezel / digital crown / Galaxy touch bezel -> mouse-wheel steps
 *    (love.wheelmoved).  Lua turns those into menu up/down or map zoom.
 *  - Hardware Back button -> keypad Enter, which the game binds to START.
 *    (Leave the game with the Home button; the game keeps running paused.)
 *  - When the game really closes (EXIT on the title menu, swiped away), the
 *    process ends with it.  SDL/LOVE keep native and static state that does
 *    not survive a second start in the same process, which is what left the
 *    app unable to reopen; a fresh process boots straight into the game.
 */
public class WearGameActivity extends GameActivity {

    private static final String DEFAULT_LAUNCH = "gen1recomp++://launch?game=firered";

    /** AXIS_SCROLL units per wheel step.  A Galaxy bezel click is ~1.0; a
     *  crown sends many small values, which accumulate to the same step. */
    private static final float ROTARY_STEP = 1.0f;

    private float rotaryAccum = 0f;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // Device language for the Lua side (src/core/WatchText.lua): the
        // watch's own screens and the automatic translation-mod choice.
        try {
            android.system.Os.setenv("POKEPORT_LOCALE",
                    java.util.Locale.getDefault().toLanguageTag(), true);
        } catch (Exception e) {
            // keep going in English
        }
        // Where the game surface sits on the physical display, for the Lua
        // side's round-face centring (src/core/Watch.lua).  The file is
        // rewritten on every layout change; its path goes in the environment
        // now, before the native side starts.
        try {
            File dir = getExternalFilesDir(null);
            if (dir == null) dir = getFilesDir();
            viewportFile = new File(dir, "watch_viewport.txt");
            android.system.Os.setenv("POKEPORT_VIEWPORT_FILE", viewportFile.getAbsolutePath(), true);
        } catch (Exception e) {
            viewportFile = null;
        }
        // Gets the ROM onto the watch while the game waits for it: Wi-Fi
        // upload page with a QR code, and a search of the watch's storage.
        // Idle (and gone after a few seconds) unless src/core/WatchBoot.lua
        // asks through the files in this folder.
        try {
            File dir = getExternalFilesDir(null);
            if (dir == null) dir = getFilesDir();
            android.system.Os.setenv("POKEPORT_ROM_INBOX", dir.getAbsolutePath(), true);
            new RomInbox(this, dir).start();
        } catch (Exception e) {
            // the waiting screen falls back to the adb instructions
        }
        Intent intent = getIntent();
        if (intent == null || intent.getData() == null) {
            Intent boot = (intent != null) ? new Intent(intent) : new Intent(Intent.ACTION_MAIN);
            boot.setData(Uri.parse(DEFAULT_LAUNCH));
            setIntent(boot);
        }
        super.onCreate(savedInstanceState);
        try {
            getWindow().getDecorView().getViewTreeObserver().addOnGlobalLayoutListener(
                    new ViewTreeObserver.OnGlobalLayoutListener() {
                        @Override
                        public void onGlobalLayout() {
                            publishViewport();
                        }
                    });
        } catch (Exception e) {
            // no centring hint; Lua falls back to the display size
        }
    }

    private File viewportFile;
    private String lastViewport;

    /** "surfaceX,surfaceY,surfaceW,surfaceH,displayW,displayH" in pixels. */
    private void publishViewport() {
        if (viewportFile == null) return;
        try {
            View v = SDLActivity.mSurface;
            if (v == null || v.getWidth() <= 0 || v.getHeight() <= 0) return;
            int[] loc = new int[2];
            v.getLocationOnScreen(loc);
            android.util.DisplayMetrics dm = new android.util.DisplayMetrics();
            android.view.Display d = android.os.Build.VERSION.SDK_INT >= 30
                    ? getDisplay() : getWindowManager().getDefaultDisplay();
            d.getRealMetrics(dm);
            String line = loc[0] + "," + loc[1] + "," + v.getWidth() + "," + v.getHeight()
                    + "," + dm.widthPixels + "," + dm.heightPixels;
            if (line.equals(lastViewport)) return;
            lastViewport = line;
            File tmp = new File(viewportFile.getPath() + ".tmp");
            FileOutputStream out = new FileOutputStream(tmp, false);
            out.write((line + "\n").getBytes("UTF-8"));
            out.close();
            if (!tmp.renameTo(viewportFile)) {
                viewportFile.delete();
                tmp.renameTo(viewportFile);
            }
            android.util.Log.d("WearGameActivity", "viewport " + line);
        } catch (Exception e) {
            // keep the previous hint
        }
    }

    /**
     * SDL asks Android for an orientation derived from LOVE's window hint
     * (conf.lua's 1080x1920 portrait/resizable phone hint).  A round watch
     * never rotates, and on the API 37 Wear emulator such a request left the
     * app window wider than the 384x384 display, pushing the game off centre.
     * So the watch never requests one.
     */
    @Override
    public void setOrientationBis(int w, int h, boolean resizable, String hint) {
        // intentionally empty
    }

    /** Same reason: also swallows the Lua side's ORIENTATION option (JNI). */
    @Override
    public void setRequestedOrientation(int requestedOrientation) {
        // intentionally empty
    }

    @Override
    protected void onDestroy() {
        boolean closing = isFinishing();
        super.onDestroy();
        if (closing) {
            // see the class comment: never reuse this process for a new start
            android.os.Process.killProcess(android.os.Process.myPid());
        }
    }

    @Override
    public boolean dispatchGenericMotionEvent(MotionEvent ev) {
        if (ev.getAction() == MotionEvent.ACTION_SCROLL
                && ev.isFromSource(InputDevice.SOURCE_ROTARY_ENCODER)) {
            // Clockwise is negative AXIS_SCROLL, which is also "wheel down"
            // for SDL / LOVE, so the sign passes straight through.
            rotaryAccum += ev.getAxisValue(MotionEvent.AXIS_SCROLL);
            while (rotaryAccum >= ROTARY_STEP) {
                rotaryAccum -= ROTARY_STEP;
                sendWheel(1f);
            }
            while (rotaryAccum <= -ROTARY_STEP) {
                rotaryAccum += ROTARY_STEP;
                sendWheel(-1f);
            }
            return true;
        }
        return super.dispatchGenericMotionEvent(ev);
    }

    private static void sendWheel(float y) {
        try {
            SDLActivity.onNativeMouse(0, MotionEvent.ACTION_SCROLL, 0f, y, false);
        } catch (UnsatisfiedLinkError e) {
            // native side not loaded yet (very first frames): drop the step
        }
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (event.getKeyCode() == KeyEvent.KEYCODE_BACK) {
            // Straight into SDL's keyboard path: the Back key's input source
            // is not always flagged as a keyboard, which SDL would ignore.
            try {
                if (event.getAction() == KeyEvent.ACTION_DOWN && event.getRepeatCount() == 0) {
                    SDLActivity.onNativeKeyDown(KeyEvent.KEYCODE_NUMPAD_ENTER);
                } else if (event.getAction() == KeyEvent.ACTION_UP) {
                    SDLActivity.onNativeKeyUp(KeyEvent.KEYCODE_NUMPAD_ENTER);
                }
            } catch (UnsatisfiedLinkError e) {
                // native side not ready yet
            }
            return true;
        }
        return super.dispatchKeyEvent(event);
    }
}
