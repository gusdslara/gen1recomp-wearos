package com.wearports.firered;

import java.util.HashMap;
import java.util.Map;

/**
 * The upload page RomInbox serves to a phone or PC on the watch's Wi-Fi, and
 * the short messages both sides show, in the watch's language.
 */
final class Page {

    private Page() {}

    private static final Map<String, Map<String, String>> T = new HashMap<>();

    private static void lang(String code, String... kv) {
        Map<String, String> m = new HashMap<>();
        for (int i = 0; i + 1 < kv.length; i += 2) m.put(kv[i], kv[i + 1]);
        T.put(code, m);
    }

    static {
        lang("pt",
                "title", "Enviar ROM para o relógio",
                "hint", "Escolha o arquivo .gba do Pokémon FireRed (USA) v1.0. Também aceita a ROM traduzida (PT-BR, ES, FR, IT) para o jogo abrir no idioma do relógio.",
                "pick", "Escolher arquivo .gba",
                "langLabel", "Se for ROM traduzida, idioma:",
                "auto", "Detectar",
                "sending", "Enviando",
                "notNeeded", "O relógio já tem a ROM.",
                "notRom", "Isso não é uma ROM de GBA (16 MB).",
                "notFireRed", "Não é Pokémon FireRed.",
                "okGame", "ROM recebida! Olhe o relógio.",
                "okLang", "ROM de idioma recebida",
                "whichLang", "ROM traduzida: escolha o idioma e envie de novo.",
                "esOfficial", "A FireRed espanhola oficial ainda não é suportada.",
                "cut", "O envio foi interrompido. Tente de novo.",
                "noSpace", "Não deu para salvar no relógio (espaço?).");
        lang("es",
                "title", "Enviar ROM al reloj",
                "hint", "Elige el archivo .gba de Pokémon FireRed (USA) v1.0. También acepta la ROM traducida (PT-BR, ES, FR, IT) para jugar en el idioma del reloj.",
                "pick", "Elegir archivo .gba",
                "langLabel", "Si es una ROM traducida, idioma:",
                "auto", "Detectar",
                "sending", "Enviando",
                "notNeeded", "El reloj ya tiene la ROM.",
                "notRom", "No es una ROM de GBA (16 MB).",
                "notFireRed", "No es Pokémon FireRed.",
                "okGame", "¡ROM recibida! Mira el reloj.",
                "okLang", "ROM de idioma recibida",
                "whichLang", "ROM traducida: elige el idioma y envíala otra vez.",
                "esOfficial", "La FireRed española oficial aún no es compatible.",
                "cut", "El envío se interrumpió. Inténtalo de nuevo.",
                "noSpace", "No se pudo guardar en el reloj (¿espacio?).");
        lang("en",
                "title", "Send the ROM to the watch",
                "hint", "Pick the Pokémon FireRed (USA) v1.0 .gba file. A translated ROM (PT-BR, ES, FR, IT) is accepted too, so the game opens in the watch's language.",
                "pick", "Choose .gba file",
                "langLabel", "If it is a translated ROM, language:",
                "auto", "Detect",
                "sending", "Sending",
                "notNeeded", "The watch already has the ROM.",
                "notRom", "That is not a GBA ROM (16 MB).",
                "notFireRed", "That is not Pokémon FireRed.",
                "okGame", "ROM received! Look at the watch.",
                "okLang", "Language ROM received",
                "whichLang", "Translated ROM: pick its language and send it again.",
                "esOfficial", "The official Spanish FireRed is not supported yet.",
                "cut", "The transfer was cut off. Try again.",
                "noSpace", "Could not save it on the watch (space?).");
        lang("fr",
                "title", "Envoyer la ROM à la montre",
                "hint", "Choisissez le fichier .gba de Pokémon FireRed (USA) v1.0. Une ROM traduite (PT-BR, ES, FR, IT) est aussi acceptée, pour jouer dans la langue de la montre.",
                "pick", "Choisir le fichier .gba",
                "langLabel", "Si c'est une ROM traduite, langue :",
                "auto", "Détecter",
                "sending", "Envoi",
                "notNeeded", "La montre a déjà la ROM.",
                "notRom", "Ce n'est pas une ROM GBA (16 Mo).",
                "notFireRed", "Ce n'est pas Pokémon FireRed.",
                "okGame", "ROM reçue ! Regardez la montre.",
                "okLang", "ROM de langue reçue",
                "whichLang", "ROM traduite : choisissez la langue et renvoyez-la.",
                "esOfficial", "La FireRed espagnole officielle n'est pas encore prise en charge.",
                "cut", "L'envoi a été interrompu. Réessayez.",
                "noSpace", "Impossible d'enregistrer sur la montre (espace ?).");
        lang("it",
                "title", "Invia la ROM all'orologio",
                "hint", "Scegli il file .gba di Pokémon FireRed (USA) v1.0. È accettata anche la ROM tradotta (PT-BR, ES, FR, IT), per giocare nella lingua dell'orologio.",
                "pick", "Scegli il file .gba",
                "langLabel", "Se è una ROM tradotta, lingua:",
                "auto", "Rileva",
                "sending", "Invio",
                "notNeeded", "L'orologio ha già la ROM.",
                "notRom", "Non è una ROM GBA (16 MB).",
                "notFireRed", "Non è Pokémon FireRed.",
                "okGame", "ROM ricevuta! Guarda l'orologio.",
                "okLang", "ROM della lingua ricevuta",
                "whichLang", "ROM tradotta: scegli la lingua e inviala di nuovo.",
                "esOfficial", "La FireRed spagnola ufficiale non è ancora supportata.",
                "cut", "L'invio si è interrotto. Riprova.",
                "noSpace", "Impossibile salvare sull'orologio (spazio?).");
        lang("de",
                "title", "ROM an die Uhr senden",
                "hint", "Wähle die .gba-Datei von Pokémon FireRed (USA) v1.0. Eine übersetzte ROM (PT-BR, ES, FR, IT) geht auch, damit das Spiel in der Sprache der Uhr startet.",
                "pick", ".gba-Datei wählen",
                "langLabel", "Bei einer übersetzten ROM, Sprache:",
                "auto", "Erkennen",
                "sending", "Senden",
                "notNeeded", "Die Uhr hat die ROM schon.",
                "notRom", "Das ist keine GBA-ROM (16 MB).",
                "notFireRed", "Das ist nicht Pokémon FireRed.",
                "okGame", "ROM empfangen! Schau auf die Uhr.",
                "okLang", "Sprach-ROM empfangen",
                "whichLang", "Übersetzte ROM: Sprache wählen und nochmal senden.",
                "esOfficial", "Die offizielle spanische FireRed wird noch nicht unterstützt.",
                "cut", "Die Übertragung brach ab. Nochmal versuchen.",
                "noSpace", "Konnte nicht auf der Uhr speichern (Speicher?).");
        lang("ru",
                "title", "Отправить ROM на часы",
                "hint", "Выберите файл .gba Pokémon FireRed (USA) v1.0. Можно и переведённый ROM (PT-BR, ES, FR, IT), чтобы игра шла на языке часов.",
                "pick", "Выбрать файл .gba",
                "langLabel", "Если ROM переведён, язык:",
                "auto", "Определить",
                "sending", "Отправка",
                "notNeeded", "На часах уже есть ROM.",
                "notRom", "Это не ROM GBA (16 МБ).",
                "notFireRed", "Это не Pokémon FireRed.",
                "okGame", "ROM получен! Посмотрите на часы.",
                "okLang", "ROM языка получен",
                "whichLang", "Переведённый ROM: выберите язык и отправьте снова.",
                "esOfficial", "Официальная испанская FireRed пока не поддерживается.",
                "cut", "Передача прервалась. Попробуйте снова.",
                "noSpace", "Не удалось сохранить на часах (место?).");
    }

    static String t(String lang, String key) {
        Map<String, String> m = T.get(lang);
        String v = m != null ? m.get(key) : null;
        if (v == null) v = T.get("en").get(key);
        return v != null ? v : key;
    }

    private static String esc(String s) {
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
    }

    static String html(String lang) {
        return "<!doctype html><html lang=\"" + esc(lang) + "\"><head><meta charset=\"utf-8\">"
                + "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
                + "<title>" + esc(t(lang, "title")) + "</title><style>"
                + "body{margin:0;font-family:system-ui,sans-serif;background:#111;color:#eee;display:flex;justify-content:center}"
                + "main{max-width:420px;width:100%;padding:24px 16px;box-sizing:border-box}"
                + "h1{font-size:22px;margin:0 0 12px}p{line-height:1.45;color:#bbb;font-size:15px}"
                + "label.btn{display:block;text-align:center;background:#e2532f;color:#fff;font-weight:600;"
                + "padding:16px;border-radius:12px;margin:20px 0;font-size:17px;cursor:pointer}"
                + "input[type=file]{display:none}select{font-size:15px;padding:6px;border-radius:8px;margin-left:6px}"
                + ".bar{height:10px;background:#333;border-radius:5px;overflow:hidden;margin-top:18px;display:none}"
                + ".bar div{height:100%;width:0;background:#e2532f}#msg{margin-top:14px;font-size:16px;min-height:1.4em}"
                + ".ok{color:#7ddc7d}.err{color:#ff7b6b}</style></head><body><main>"
                + "<h1>" + esc(t(lang, "title")) + "</h1>"
                + "<p>" + esc(t(lang, "hint")) + "</p>"
                + "<label class=\"btn\">" + esc(t(lang, "pick")) + "<input id=\"f\" type=\"file\" accept=\".gba,application/octet-stream\"></label>"
                + "<p>" + esc(t(lang, "langLabel")) + "<select id=\"l\"><option value=\"\">" + esc(t(lang, "auto")) + "</option>"
                + "<option value=\"pt\">Português (BR)</option><option value=\"es\">Español</option>"
                + "<option value=\"fr\">Français</option><option value=\"it\">Italiano</option></select></p>"
                + "<div class=\"bar\" id=\"b\"><div id=\"p\"></div></div><div id=\"msg\"></div>"
                + "<script>"
                + "var S=" + jsString(t(lang, "sending")) + ";"
                + "document.getElementById('f').onchange=function(){var f=this.files[0];if(!f)return;"
                + "var m=document.getElementById('msg'),b=document.getElementById('b'),p=document.getElementById('p');"
                + "m.className='';m.textContent=S+'...';b.style.display='block';p.style.width='0';"
                + "var x=new XMLHttpRequest();"
                + "x.open('POST','/upload?name='+encodeURIComponent(f.name)+'&lang='+document.getElementById('l').value);"
                + "x.upload.onprogress=function(e){if(e.lengthComputable){var k=Math.round(e.loaded*100/e.total);"
                + "p.style.width=k+'%';m.textContent=S+' '+k+'%';}};"
                + "x.onload=function(){var r={};try{r=JSON.parse(x.responseText)}catch(e){r={ok:false,msg:x.status}}"
                + "m.className=r.ok?'ok':'err';m.textContent=r.msg;p.style.width=r.ok?'100%':'0';};"
                + "x.onerror=function(){m.className='err';m.textContent=" + jsString(t(lang, "cut")) + ";};"
                + "x.send(f);this.value='';};"
                + "</script></main></body></html>";
    }

    private static String jsString(String s) {
        return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"").replace("</", "<\\/") + "\"";
    }
}
