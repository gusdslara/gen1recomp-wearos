package com.wearports.firered;

import android.app.Activity;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.LinkAddress;
import android.net.LinkProperties;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;
import android.util.Log;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.NetworkInterface;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.URLDecoder;
import java.security.MessageDigest;
import java.util.ArrayDeque;
import java.util.Collections;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Gets the FireRed ROM onto the watch while the game waits for it
 * (src/core/WatchBoot.lua shows the round "send the ROM" screen).
 *
 *  - Wi-Fi: brings Wi-Fi up (a watch paired to a phone keeps it off), runs a
 *    tiny HTTP server and publishes its URL plus a QR code of it.  A phone or
 *    PC on the same network (or a phone sharing its hotspot with the watch)
 *    opens the page, picks the .gba and sends it.
 *  - Storage: looks for .gba files anywhere in the watch's shared storage
 *    (Download/, Documents/, ...).  On Wear OS 4+ other apps' files are only
 *    visible with "All files access", which the watch screen offers to open.
 *
 * Whatever arrives is checked (FireRed header, SHA-1): the USA ROM goes to
 * the game's save folder, where WatchBoot imports it; a translated FireRed
 * goes to idioma/ for src/core/WatchTranslate.lua.
 *
 * Talks to Lua through two small files in getExternalFilesDir() (path in
 * POKEPORT_ROM_INBOX): rom_inbox_ctl.txt (Lua -> here: want, save folder,
 * permission requests) and rom_inbox_status.txt (here -> Lua: Wi-Fi, URL, QR,
 * progress, messages).  Does nothing unless Lua asks, and the thread ends
 * once the game no longer needs a ROM.
 */
final class RomInbox implements Runnable {

    private static final String TAG = "RomInbox";
    static final String USA_SHA1 = "41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc";
    static final long ROM_SIZE = 16L * 1024 * 1024;
    private static final long MAX_UPLOAD = 64L * 1024 * 1024;
    /** Ends the thread when Lua never asks (game already imported). */
    private static final long IDLE_EXIT_MS = 20000;
    private volatile boolean done;

    private final Activity activity;
    private final File ctlFile;
    private final File statusFile;
    private final String lang;
    private final long bornAt = System.currentTimeMillis();

    // from Lua
    private volatile boolean want;
    private volatile boolean everWanted;
    private volatile File saveDir;
    private int permAsked;

    // Wi-Fi
    private ConnectivityManager cm;
    private ConnectivityManager.NetworkCallback wifiCallback;
    private volatile String wifi = "off";   // off | starting | on | none
    private volatile String ip;
    private long wifiRetryAt;

    // HTTP
    private ServerSocket server;
    private int port;
    private String qrUrl;
    private String qrRows;
    private int qrSize;

    // what Lua shows
    private volatile String state = "idle"; // idle | waiting | receiving | checking | accepted | error
    private volatile int progress = -1;
    private volatile String msg = "";
    private String lastStatus;

    // storage scan
    private final Map<String, Long> seen = new HashMap<>();
    private long nextScan;

    RomInbox(Activity activity, File dir) {
        this.activity = activity;
        this.ctlFile = new File(dir, "rom_inbox_ctl.txt");
        this.statusFile = new File(dir, "rom_inbox_status.txt");
        this.lang = Locale.getDefault().getLanguage();
        // a request left by an earlier run must not start anything
        ctlFile.delete();
        statusFile.delete();
    }

    void start() {
        Thread t = new Thread(this, "rom-inbox");
        t.setDaemon(true);
        t.start();
    }

    @Override
    public void run() {
        while (true) {
            try {
                tick();
            } catch (Throwable e) {
                Log.w(TAG, "tick", e);
            }
            long now = System.currentTimeMillis();
            if (done || (!everWanted && now - bornAt > IDLE_EXIT_MS)) {
                stopAll();
                writeStatus();
                Log.d(TAG, "done");
                return;
            }
            try {
                // while the ROM imports nothing is served: look in less often
                Thread.sleep(want ? 600 : 2000);
            } catch (InterruptedException e) {
                stopAll();
                return;
            }
        }
    }

    private void tick() {
        readCtl();
        if (!want) {
            stopAll();
        } else if (saveDir != null) {
            everWanted = true;
            if (state.equals("idle")) state = "waiting";
            ensureServer();
            ensureWifi();
            long now = System.currentTimeMillis();
            if (now >= nextScan) {
                nextScan = now + 4000;
                scanStorage();
            }
        }
        writeStatus();
    }

    // ------------------------------------------------------------ Lua link

    private void readCtl() {
        String text = readSmall(ctlFile);
        if (text == null) return;
        boolean w = false;
        File save = null;
        int perm = 0;
        for (String line : text.split("\n")) {
            int eq = line.indexOf('=');
            if (eq < 0) continue;
            String k = line.substring(0, eq).trim();
            String v = line.substring(eq + 1).trim();
            if (k.equals("want")) w = v.equals("1");
            else if (k.equals("done")) done = v.equals("1");
            else if (k.equals("save") && !v.isEmpty()) save = new File(v);
            else if (k.equals("perm")) {
                try { perm = Integer.parseInt(v); } catch (NumberFormatException e) { perm = 0; }
            }
        }
        want = w;
        if (save != null) saveDir = save;
        if (perm > permAsked) {
            permAsked = perm;
            askAllFilesAccess();
        }
    }

    private synchronized void writeStatus() {
        StringBuilder sb = new StringBuilder();
        sb.append("state=").append(want ? state : "idle").append('\n');
        sb.append("wifi=").append(wifi).append('\n');
        sb.append("perm=").append(hasAllFiles() ? "1" : "0").append('\n');
        if (progress >= 0) sb.append("progress=").append(progress).append('\n');
        if (!msg.isEmpty()) sb.append("msg=").append(msg.replace('\n', ' ')).append('\n');
        String url = (ip != null && server != null) ? "http://" + ip + ":" + port : null;
        if (url != null) {
            if (!url.equals(qrUrl)) makeQr(url);
            sb.append("url=").append(url).append('\n');
            if (qrRows != null) {
                sb.append("qrsize=").append(qrSize).append('\n');
                sb.append("qr=").append(qrRows).append('\n');
            }
        }
        String text = sb.toString();
        if (text.equals(lastStatus)) return;
        lastStatus = text;
        writeAtomically(statusFile, text.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    private void makeQr(String url) {
        qrUrl = url;
        qrRows = null;
        try {
            Map<EncodeHintType, Object> hints = new EnumMap<>(EncodeHintType.class);
            hints.put(EncodeHintType.MARGIN, 0);
            hints.put(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.L);
            BitMatrix m = new QRCodeWriter().encode(url, BarcodeFormat.QR_CODE, 1, 1, hints);
            int n = m.getWidth();
            StringBuilder sb = new StringBuilder(n * n);
            for (int y = 0; y < n; y++) {
                for (int x = 0; x < n; x++) sb.append(m.get(x, y) ? '1' : '0');
            }
            qrSize = n;
            qrRows = sb.toString();
        } catch (Exception e) {
            Log.w(TAG, "qr", e);
        }
    }

    // -------------------------------------------------------------- Wi-Fi

    private void ensureWifi() {
        if (wifiCallback != null || System.currentTimeMillis() < wifiRetryAt) return;
        if (cm == null) cm = (ConnectivityManager) activity.getSystemService(Activity.CONNECTIVITY_SERVICE);
        if (cm == null) return;
        wifi = "starting";
        // Any Wi-Fi, with or without internet (a phone hotspot or a plain router).
        NetworkRequest req = new NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build();
        wifiCallback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(Network network) {
                ip = ipv4(cm.getLinkProperties(network));
                if (ip == null) ip = wlanIp();
                wifi = ip != null ? "on" : "starting";
            }

            @Override
            public void onLinkPropertiesChanged(Network network, LinkProperties lp) {
                String a = ipv4(lp);
                if (a != null) {
                    ip = a;
                    wifi = "on";
                }
            }

            @Override
            public void onLost(Network network) {
                ip = null;
                wifi = "starting";
            }

            @Override
            public void onUnavailable() {
                // no known Wi-Fi in range: try again in a while
                ip = null;
                wifi = "none";
                wifiCallback = null;
                wifiRetryAt = System.currentTimeMillis() + 20000;
            }
        };
        try {
            cm.requestNetwork(req, wifiCallback, 30000);
        } catch (Exception e) {
            Log.w(TAG, "requestNetwork", e);
            wifiCallback = null;
            wifi = "none";
            wifiRetryAt = System.currentTimeMillis() + 20000;
        }
    }

    private static String ipv4(LinkProperties lp) {
        if (lp == null) return null;
        for (LinkAddress la : lp.getLinkAddresses()) {
            InetAddress a = la.getAddress();
            if (a instanceof Inet4Address && !a.isLoopbackAddress()) return a.getHostAddress();
        }
        return null;
    }

    private static String wlanIp() {
        try {
            for (NetworkInterface nif : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!nif.isUp() || !nif.getName().startsWith("wlan")) continue;
                for (InetAddress a : Collections.list(nif.getInetAddresses())) {
                    if (a instanceof Inet4Address && !a.isLoopbackAddress()) return a.getHostAddress();
                }
            }
        } catch (Exception e) {
            // none
        }
        return null;
    }

    private void stopAll() {
        if (wifiCallback != null && cm != null) {
            try { cm.unregisterNetworkCallback(wifiCallback); } catch (Exception e) { /* gone */ }
        }
        wifiCallback = null;
        ip = null;
        wifi = "off";
        if (server != null) {
            try { server.close(); } catch (IOException e) { /* closed */ }
        }
        server = null;
        state = "idle";
    }

    // --------------------------------------------------------------- HTTP

    private void ensureServer() {
        if (server != null) return;
        for (int p = 8080; p <= 8090 && server == null; p++) {
            try {
                ServerSocket s = new ServerSocket();
                s.setReuseAddress(true);
                s.bind(new InetSocketAddress(p));
                server = s;
                port = p;
            } catch (IOException e) {
                // port taken, next
            }
        }
        if (server == null) return;
        final ServerSocket s = server;
        Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                while (!s.isClosed()) {
                    try {
                        Socket c = s.accept();
                        c.setSoTimeout(30000);
                        try {
                            handle(c);
                        } catch (Exception e) {
                            Log.w(TAG, "request", e);
                        } finally {
                            try { c.close(); } catch (IOException e) { /* closed */ }
                        }
                    } catch (IOException e) {
                        // server closed
                    }
                }
            }
        }, "rom-inbox-http");
        t.setDaemon(true);
        t.start();
        Log.d(TAG, "listening on " + port);
    }

    private void handle(Socket c) throws Exception {
        InputStream in = new BufferedInputStream(c.getInputStream(), 65536);
        OutputStream out = c.getOutputStream();
        String head = readHead(in);
        if (head == null) return;
        String[] lines = head.split("\r\n");
        String[] first = lines[0].split(" ");
        if (first.length < 2) return;
        String method = first[0];
        String target = first[1];
        long length = -1;
        for (int i = 1; i < lines.length; i++) {
            int colon = lines[i].indexOf(':');
            if (colon > 0 && lines[i].substring(0, colon).trim().equalsIgnoreCase("content-length")) {
                try { length = Long.parseLong(lines[i].substring(colon + 1).trim()); } catch (NumberFormatException e) { length = -1; }
            }
        }
        String path = target;
        Map<String, String> query = new HashMap<>();
        int q = target.indexOf('?');
        if (q >= 0) {
            path = target.substring(0, q);
            for (String kv : target.substring(q + 1).split("&")) {
                int eq = kv.indexOf('=');
                if (eq > 0) query.put(kv.substring(0, eq), URLDecoder.decode(kv.substring(eq + 1), "UTF-8"));
            }
        }
        if (method.equals("GET") && (path.equals("/") || path.equals("/index.html"))) {
            send(out, 200, "text/html; charset=utf-8", Page.html(lang).getBytes("UTF-8"));
        } else if (method.equals("POST") && path.equals("/upload")) {
            if (!want) {
                send(out, 409, "application/json", json(false, Page.t(lang, "notNeeded")));
            } else if (length <= 0 || length > MAX_UPLOAD) {
                send(out, 413, "application/json", json(false, Page.t(lang, "notRom")));
            } else {
                send(out, 200, "application/json", receive(in, length, query.get("name"), query.get("lang")));
            }
        } else {
            send(out, 404, "text/plain", "not found".getBytes("UTF-8"));
        }
    }

    private static String readHead(InputStream in) throws IOException {
        ByteArrayOutputStream b = new ByteArrayOutputStream();
        int state = 0;
        while (b.size() < 16384) {
            int c = in.read();
            if (c < 0) return null;
            b.write(c);
            if ((state == 0 || state == 2) && c == '\r') state++;
            else if ((state == 1 || state == 3) && c == '\n') state++;
            else state = (c == '\r') ? 1 : 0;
            if (state == 4) return b.toString("ISO-8859-1");
        }
        return null;
    }

    private static void send(OutputStream out, int code, String type, byte[] body) throws IOException {
        String head = "HTTP/1.1 " + code + (code == 200 ? " OK" : " Error") + "\r\n"
                + "Content-Type: " + type + "\r\n"
                + "Content-Length: " + body.length + "\r\n"
                + "Cache-Control: no-store\r\n"
                + "Connection: close\r\n\r\n";
        out.write(head.getBytes("ISO-8859-1"));
        out.write(body);
        out.flush();
    }

    private byte[] receive(InputStream in, long length, String name, String langHint) throws Exception {
        File inbox = new File(saveDir, ".inbox");
        inbox.mkdirs();
        File tmp = new File(inbox, "upload.tmp");
        MessageDigest sha = MessageDigest.getInstance("SHA-1");
        state = "receiving";
        progress = 0;
        msg = "";
        writeStatus();
        long got = 0;
        try (FileOutputStream f = new FileOutputStream(tmp)) {
            byte[] buf = new byte[65536];
            long lastShown = 0;
            while (got < length) {
                int n = in.read(buf, 0, (int) Math.min(buf.length, length - got));
                if (n < 0) break;
                f.write(buf, 0, n);
                sha.update(buf, 0, n);
                got += n;
                progress = (int) (got * 100 / length);
                long now = System.currentTimeMillis();
                if (now - lastShown > 300) {
                    lastShown = now;
                    writeStatus();
                }
            }
        }
        progress = -1;
        if (got < length) {
            tmp.delete();
            state = "error";
            msg = Page.t(lang, "cut");
            return json(false, msg);
        }
        Verdict v = place(tmp, hex(sha.digest()), name, langHint, true);
        return json(v.ok, v.text);
    }

    private static byte[] json(boolean ok, String text) {
        String t = text.replace("\\", "\\\\").replace("\"", "\\\"");
        try {
            return ("{\"ok\":" + ok + ",\"msg\":\"" + t + "\"}").getBytes("UTF-8");
        } catch (Exception e) {
            return new byte[0];
        }
    }

    // ----------------------------------------------------------- checking

    static final class Verdict {
        final boolean ok;
        final String text;
        Verdict(boolean ok, String text) { this.ok = ok; this.text = text; }
    }

    /**
     * Checks a candidate ROM and moves (upload) or copies (found in storage)
     * it where the game picks it up.
     */
    private synchronized Verdict place(File src, String sha1, String name, String langHint, boolean move) {
        String before = state;
        if (move) {
            state = "checking";
            writeStatus();
        }
        Verdict v;
        try {
            v = placeUnchecked(src, sha1, name, langHint, move);
        } catch (Exception e) {
            Log.w(TAG, "place", e);
            v = new Verdict(false, Page.t(lang, "notRom"));
        }
        if (move && src.exists()) src.delete();
        if (v.ok || move) {
            state = v.ok ? "accepted" : "error";
            msg = v.text;
        } else {
            // a file found in storage that is not for us: say nothing
            state = before;
        }
        writeStatus();
        return v;
    }

    private Verdict placeUnchecked(File src, String sha1, String name, String langHint, boolean move) throws IOException {
        if (src.length() != ROM_SIZE) return new Verdict(false, Page.t(lang, "notRom"));
        byte[] h = new byte[16];
        try (RandomAccessFile r = new RandomAccessFile(src, "r")) {
            r.seek(0xA0);
            r.readFully(h);
        }
        String title = new String(h, 0, 12, "ISO-8859-1");
        String code = new String(h, 12, 4, "ISO-8859-1");
        if (!title.equals("POKEMON FIRE")) return new Verdict(false, Page.t(lang, "notFireRed"));
        File dest;
        String okText;
        String l = languageOf(code, name, langHint);

        // Se for a ROM USA pura ou se ainda não temos a ROM base americana (firered.gba)
        File baseGba = new File(saveDir, "firered.gba");
        if (USA_SHA1.equals(sha1) || !baseGba.exists()) {
            dest = baseGba;
            okText = Page.t(lang, "okGame");

            // Se o usuário brasileiro enviou a ROM PT-BR direto no primeiro uso como ROM base,
            // também guardamos uma cópia em idioma/firered_ptbr.gba para o WatchTranslate ativar os textos em português!
            if (l != null && !USA_SHA1.equals(sha1)) {
                File dir = new File(saveDir, "idioma");
                dir.mkdirs();
                File langFile = new File(dir, l.equals("pt") ? "firered_ptbr.gba" : "firered_" + l + ".gba");
                try {
                    copy(src, langFile);
                } catch (Exception ignored) {}
            }
        } else {
            if (l == null) {
                return new Verdict(false, code.equals("BPRS") ? Page.t(lang, "esOfficial") : Page.t(lang, "whichLang"));
            }
            File dir = new File(saveDir, "idioma");
            dir.mkdirs();
            dest = new File(dir, l.equals("pt") ? "firered_ptbr.gba" : "firered_" + l + ".gba");
            okText = Page.t(lang, "okLang") + " (" + l.toUpperCase(Locale.ROOT) + ")";
        }
        File tmp = new File(dest.getPath() + ".part");
        if (move) {
            if (!src.renameTo(tmp)) copy(src, tmp);
        } else {
            copy(src, tmp);
        }
        dest.delete();
        if (!tmp.renameTo(dest)) {
            tmp.delete();
            return new Verdict(false, Page.t(lang, "noSpace"));
        }
        Log.d(TAG, "placed " + dest);
        return new Verdict(true, okText);
    }

    /** pt / es / fr / it for a translated FireRed, or null when unsure. */
    private static String languageOf(String code, String name, String hint) {
        if (hint != null && (hint.equals("pt") || hint.equals("es") || hint.equals("fr") || hint.equals("it"))) return hint;
        if (code.equals("BPRF")) return "fr";
        if (code.equals("BPRI")) return "it";
        if (!code.equals("BPRE")) return null;  // the recipes cover fan patches of the US ROM
        String n = name == null ? "" : name.toLowerCase(Locale.ROOT);
        if (n.matches(".*(pt[-_ ]?br|ptbr|portug|brasil|brazil|_pt\\b|\\bpt\\b|-pt\\.).*")) return "pt";
        if (n.matches(".*(espa|spanish|\\bes\\b|_es\\b|-es\\.|castell).*")) return "es";
        return null;
    }

    private static void copy(File a, File b) throws IOException {
        try (FileInputStream in = new FileInputStream(a); FileOutputStream out = new FileOutputStream(b)) {
            byte[] buf = new byte[65536];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        }
    }

    private static String sha1Of(File f) throws Exception {
        MessageDigest sha = MessageDigest.getInstance("SHA-1");
        try (FileInputStream in = new FileInputStream(f)) {
            byte[] buf = new byte[65536];
            int n;
            while ((n = in.read(buf)) > 0) sha.update(buf, 0, n);
        }
        return hex(sha.digest());
    }

    private static String hex(byte[] d) {
        StringBuilder sb = new StringBuilder();
        for (byte b : d) sb.append(String.format(Locale.ROOT, "%02x", b & 0xff));
        return sb.toString();
    }

    // ------------------------------------------------------- storage scan

    private boolean hasAllFiles() {
        if (Build.VERSION.SDK_INT >= 30) return Environment.isExternalStorageManager();
        return true;
    }

    private void askAllFilesAccess() {
        final String pkg = activity.getPackageName();
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    activity.startActivity(new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                            Uri.parse("package:" + pkg)));
                    return;
                } catch (Exception e) {
                    // not on this watch
                }
                try {
                    activity.startActivity(new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION));
                    return;
                } catch (Exception e) {
                    // not on this watch either
                }
                msg = "adb shell appops set " + pkg + " MANAGE_EXTERNAL_STORAGE allow";
            }
        });
    }

    /** Every .gba of ROM size in shared storage that was not looked at yet. */
    private void scanStorage() {
        File root = Environment.getExternalStorageDirectory();
        if (root == null || saveDir == null) return;
        ArrayDeque<Object[]> todo = new ArrayDeque<>();
        todo.add(new Object[] { root, 0 });
        int visited = 0;
        while (!todo.isEmpty() && visited < 20000 && want) {
            Object[] item = todo.poll();
            File dir = (File) item[0];
            int depth = (Integer) item[1];
            File[] list = dir.listFiles();
            if (list == null) continue;
            for (File f : list) {
                visited++;
                String n = f.getName();
                if (f.isDirectory()) {
                    // Android/ holds app data (ours included); dot-folders are caches
                    if (depth < 6 && !n.startsWith(".") && !(depth == 0 && n.equals("Android"))) {
                        todo.add(new Object[] { f, depth + 1 });
                    }
                } else if (n.toLowerCase(Locale.ROOT).endsWith(".gba") && f.length() == ROM_SIZE) {
                    String key = f.getAbsolutePath();
                    Long when = seen.get(key);
                    if (when != null && when == f.lastModified()) continue;
                    seen.put(key, f.lastModified());
                    try {
                        Verdict v = place(f, sha1Of(f), n, null, false);
                        if (v.ok) msg = v.text + ": " + key.replace(root.getAbsolutePath(), "");
                    } catch (Exception e) {
                        Log.w(TAG, "scan " + key, e);
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------- files

    private static String readSmall(File f) {
        if (!f.exists()) return null;
        try (FileInputStream in = new FileInputStream(f)) {
            byte[] buf = new byte[(int) Math.min(f.length(), 8192)];
            int n = in.read(buf);
            return n <= 0 ? "" : new String(buf, 0, n, "UTF-8");
        } catch (IOException e) {
            return null;
        }
    }

    private static void writeAtomically(File f, byte[] data) {
        File tmp = new File(f.getPath() + ".tmp");
        try (FileOutputStream out = new FileOutputStream(tmp, false)) {
            out.write(data);
        } catch (IOException e) {
            return;
        }
        if (!tmp.renameTo(f)) {
            f.delete();
            tmp.renameTo(f);
        }
    }
}
